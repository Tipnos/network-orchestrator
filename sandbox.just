# sandbox.just — host-side: lifecycle, feature agents, databases, egress.
# Run from your host shell as `just sandbox::<recipe>`.

dc := "docker compose -f " + justfile_directory() / ".sandbox/compose.yml"
worktrees := justfile_directory() / ".worktrees"

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
    {{dc}} up -d --build --wait

# Stop, keeping volumes (db, caches, Claude login).
down:
    {{dc}} down

# Stop and delete all volumes.
clean:
    {{dc}} down -v

# Rebuild images without cache, then restart.
rebuild:
    {{dc}} build --no-cache
    {{dc}} up -d --wait

status:
    {{dc}} ps

# --- Shells & feature agents -------------------------------------------

# Shell in the sandbox, optionally in a feature's worktree.
shell feature="":
    {{dc}} exec -w /workspace/.worktrees/{{feature}} app bash

# Launch Claude on a feature. Creates on first use: worktree + branch
# <feature>, database app_<feature> (or `db`; `app` = shared), and a cargo
# target dir. Undo with agent-feature-clean.
agent-feature feature db="": up
    #!/usr/bin/env bash
    set -euo pipefail
    wt="{{feature}}"
    [[ "$wt" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "Invalid feature name '$wt'" >&2; exit 1; }
    db="{{db}}"; [ -n "$db" ] || db="app_${wt//-/_}"

    if [ ! -d "{{worktrees}}/$wt" ]; then
        if git show-ref --verify --quiet "refs/heads/$wt"; then
            git worktree add --relative-paths "{{worktrees}}/$wt" "$wt"
        else
            git worktree add --relative-paths "{{worktrees}}/$wt" -b "$wt"
        fi
    fi

    exists=$({{dc}} exec -T app psql -tAc "SELECT 1 FROM pg_database WHERE datname = '$db'")
    if [ "$exists" != "1" ]; then
        echo "Creating database $db"
        {{dc}} exec -T app psql -qc "CREATE DATABASE \"$db\""
    fi

    {{dc}} exec -w "/workspace/.worktrees/$wt" \
        -e CARGO_TARGET_DIR="/home/dev/target/$wt" \
        -e DATABASE_URL="postgres://postgres:postgres@db:5432/$db" \
        app claude

# Remove a feature's worktree, branch, database and target dir.
# Stops on uncommitted changes and keeps unmerged branches unless `force`.
#   just sandbox::agent-feature-clean feature-a [db] [force]
agent-feature-clean feature *opts:
    #!/usr/bin/env bash
    set -euo pipefail
    wt="{{feature}}"
    [[ "$wt" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "Invalid feature name '$wt'" >&2; exit 1; }
    path="{{worktrees}}/$wt"
    db="app_${wt//-/_}"
    force=""
    for opt in {{opts}}; do
        if [ "$opt" = "force" ]; then force=1; else db="$opt"; fi
    done

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
        echo "Sandbox not running: skipped database '$db' and target dir." >&2
        exit 0
    fi
    if [ "$db" = "app" ]; then
        echo "Not dropping the shared 'app' database"
    else
        {{dc}} exec -T app psql -qc "DROP DATABASE IF EXISTS \"$db\" WITH (FORCE)"
    fi
    {{dc}} exec -T app rm -rf "/home/dev/target/$wt"

# --- Databases ---------------------------------------------------------

# Create app_<name>.
db-new name:
    {{dc}} exec -T app psql -c 'CREATE DATABASE "app_{{replace(name, "-", "_")}}"'

# Drop app_<name>.
db-drop name:
    {{dc}} exec -T app psql -c 'DROP DATABASE IF EXISTS "app_{{replace(name, "-", "_")}}"'

db-list:
    {{dc}} exec -T app psql -c '\l'

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
    expect "internal names resolve"           "$(run getent hosts db >/dev/null && echo 1)"

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
