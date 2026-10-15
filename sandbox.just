# sandbox.just — host-side: lifecycle, feature agents, NATS, egress.
# Run from your host shell as `just sandbox::<recipe>`.

dc := "docker compose -f " + justfile_directory() / ".sandbox/compose.yml"
worktrees := justfile_directory() / ".worktrees"
nats_dir := justfile_directory() / ".sandbox/nats"

# Read by compose.yml.
export HOST_UID := `id -u`
export GIT_AUTHOR_NAME := `git config user.name || echo dev`
export GIT_AUTHOR_EMAIL := `git config user.email || echo dev@localhost`

# --- Lifecycle ---------------------------------------------------------

# Build if needed and start. Recreates containers whose config changed.
up:
    # Create it ourselves so Docker doesn't create it root-owned.
    mkdir -p {{worktrees}}
    # Relative worktree paths, so the container can mount them anywhere.
    git config worktree.useRelativePaths true
    {{nats_dir}}/accounts.sh
    {{dc}} up -d --build --wait

# Stop, keeping volumes (NATS data, caches, Claude login).
down:
    {{dc}} down

# Stop and delete all volumes, and the NATS accounts that pointed into them.
clean:
    {{dc}} down -v
    rm -rf {{nats_dir}}/accounts.d {{nats_dir}}/accounts.conf

# Rebuild images without cache, then restart.
rebuild:
    {{nats_dir}}/accounts.sh
    {{dc}} build --no-cache
    {{dc}} up -d --wait

status:
    {{dc}} ps

# --- Shells & feature agents -------------------------------------------

# Shell in the sandbox, optionally in a feature's worktree.
shell feature="":
    {{dc}} exec -w /workspace/.worktrees/{{feature}} app bash

# Launch Claude on a feature. Creates on first use: worktree + branch
# <feature>, NATS account <feature> (`.`/`-` become `_`) and a cargo target
# dir. Undo with agent-feature-clean.
agent-feature feature: up
    #!/usr/bin/env bash
    set -euo pipefail
    wt="{{feature}}"
    [[ "$wt" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "Invalid feature name '$wt'" >&2; exit 1; }

    if [ ! -d "{{worktrees}}/$wt" ]; then
        if git show-ref --verify --quiet "refs/heads/$wt"; then
            git worktree add --relative-paths "{{worktrees}}/$wt" "$wt"
        else
            git worktree add --relative-paths "{{worktrees}}/$wt" -b "$wt"
        fi
    fi

    acct="${wt//[.-]/_}"
    pw_file="{{nats_dir}}/accounts.d/$acct"
    if [ ! -f "$pw_file" ]; then
        echo "Creating NATS account $acct"
        od -An -N16 -tx1 /dev/urandom | tr -d ' \n' > "$pw_file"
        {{nats_dir}}/accounts.sh
        {{dc}} kill -s HUP nats >/dev/null
    fi

    {{dc}} exec -w "/workspace/.worktrees/$wt" \
        -e CARGO_TARGET_DIR="/home/dev/target/$wt" \
        -e NATS_URL="nats://$acct:$(cat "$pw_file")@nats:4222" \
        app claude

# Remove a feature's worktree, branch, NATS account (and its streams) and
# target dir.
# Stops on uncommitted changes and keeps unmerged branches unless `force`.
#   just sandbox::agent-feature-clean feature-a [force]
agent-feature-clean feature force="":
    #!/usr/bin/env bash
    set -euo pipefail
    wt="{{feature}}"
    [[ "$wt" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "Invalid feature name '$wt'" >&2; exit 1; }
    path="{{worktrees}}/$wt"
    force=""
    case "{{force}}" in
        "") ;;
        force) force=1 ;;
        *) echo "Unknown option '{{force}}' (expected 'force')" >&2; exit 1 ;;
    esac

    if [ -d "$path" ]; then
        if [ -n "$force" ]; then
            git worktree remove --force "$path"
        elif ! git worktree remove "$path"; then
            echo "Uncommitted changes in $path. Commit them, or re-run with 'force'." >&2
            exit 1
        fi
    fi
    git worktree prune

    if git show-ref --verify --quiet "refs/heads/$wt"; then
        git branch "$([ -n "$force" ] && echo -D || echo -d)" "$wt" \
            || echo "Kept unmerged branch '$wt'. Re-run with 'force' to delete it." >&2
    fi

    if ! {{dc}} exec -T app true 2>/dev/null; then
        echo "Sandbox not running: skipped NATS account and target dir." >&2
        exit 0
    fi
    acct="${wt//[.-]/_}"
    pw_file="{{nats_dir}}/accounts.d/$acct"
    if [ "$acct" = "shared" ]; then
        echo "Not removing the shared NATS account"
    elif [ -f "$pw_file" ]; then
        # Delete the streams (KV and object stores included) first, otherwise
        # their files stay in the volume with no account to reach them.
        url="nats://$acct:$(cat "$pw_file")@nats:4222"
        for s in $({{dc}} exec -T -e NATS_URL="$url" app nats stream ls --names); do
            {{dc}} exec -T -e NATS_URL="$url" app nats stream rm -f "$s"
        done
        rm "$pw_file"
        {{nats_dir}}/accounts.sh
        {{dc}} kill -s HUP nats >/dev/null
    fi
    {{dc}} exec -T app rm -rf "/home/dev/target/$wt"

# --- NATS --------------------------------------------------------------

# Run the nats CLI as a feature's account (`shared` for the shared one),
# e.g. `just sandbox::nats feature-a stream ls`.
nats feature *args:
    #!/usr/bin/env bash
    set -euo pipefail
    acct="$(echo "{{feature}}" | tr '.-' '__')"
    pw_file="{{nats_dir}}/accounts.d/$acct"
    [ -f "$pw_file" ] || { echo "No NATS account '$acct'" >&2; exit 1; }
    {{dc}} exec -e NATS_URL="nats://$acct:$(cat "$pw_file")@nats:4222" app nats {{args}}

# List NATS accounts.
nats-accounts:
    @ls {{nats_dir}}/accounts.d

# --- Egress ------------------------------------------------------------

# Apply edits to allowed-domains.txt or the proxy config.
proxy-reload:
    {{dc}} up -d --build --force-recreate --no-deps --wait proxy

# Proxy access log: one line per request. TCP_DENIED = not on the allowlist.
proxy-logs *args:
    {{dc}} logs {{args}} proxy

# Verify containment from inside app.
egress-check:
    #!/usr/bin/env bash
    set -uo pipefail
    run() { {{dc}} exec -T app "$@"; }
    code() { run curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$@"; }
    fail=0
    expect() { # <description> <ok?>
        if [ "$2" = 1 ]; then echo "ok    $1"; else echo "FAIL  $1" >&2; fail=1; fi
    }

    expect "allowlisted domain via proxy"     "$([ "$(code https://index.crates.io/config.json)" = 200 ] && echo 1)"
    expect "other domain refused (http 403)"  "$([ "$(code http://example.com)" = 403 ] && echo 1)"
    # A refused CONNECT has no HTTP response, so curl reports 000.
    expect "other domain refused (https)"     "$([ "$(code https://example.com)" != 200 ] && echo 1)"
    expect "no direct egress"                 "$([ "$(code --noproxy '*' https://api.github.com/zen)" = 000 ] && echo 1)"
    expect "no external DNS"                  "$(run getent hosts example.com >/dev/null || echo 1)"
    expect "internal names resolve"           "$(run getent hosts nats >/dev/null && echo 1)"

    [ "$fail" = 0 ] || exit 1

# --- Setup -------------------------------------------------------------

# Check host prerequisites.
doctor:
    #!/usr/bin/env bash
    for cmd in docker git just; do
        command -v "$cmd" >/dev/null && echo "OK    $cmd" || echo "MISSING  $cmd"
    done
    docker compose version >/dev/null 2>&1 && echo "OK    docker compose" || echo "MISSING  docker compose"
    docker ps >/dev/null 2>&1 && echo "OK    docker daemon" || echo "FAIL  docker daemon not reachable"
    v=$(git version | awk '{print $3}')
    printf '2.48\n%s\n' "$v" | sort -V -C && echo "OK    git $v" || echo "FAIL  git $v < 2.48 (relative worktrees)"
