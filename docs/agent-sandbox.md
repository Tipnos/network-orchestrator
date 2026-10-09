# Agent sandbox

Several Claude Code agents in one container, each on its own git worktree,
with egress limited to an allowlist of domains. You review their work from the
host editor in `.worktrees/`.

Not a goal: isolating agents from each other or protecting against a hostile
host.

## Architecture

`.sandbox/compose.yml`, project `network-orchestrator-sandbox`:

| Service | Networks | Role |
|---|---|---|
| `app` | `sandbox` | Where agents run. User `dev` (your UID), `cap_drop: ALL`, `no-new-privileges`. |
| `proxy` | `sandbox`, `egress` | squid. Allows `CONNECT` only to hosts in `allowed-domains.txt`. TLS is not decrypted. |
| `db` | `sandbox` | Postgres 16, port not published. |

`sandbox` is an `internal` Docker network: no gateway (IPv4 or IPv6) and no
external DNS. `proxy` is the only service that can reach the internet.

## Filesystem

- Only `.worktrees/` and `.git` are mounted (at `/workspace/`). The main
  checkout is not visible to the agent.
- Worktrees use relative paths (`worktree.useRelativePaths`, set by
  `sandbox::up`), so they resolve on both host and container. This needs git
  ≥ 2.48 on both sides; the image builds git from source because Debian's is
  older. To convert an existing worktree, run
  `git worktree repair --relative-paths`.
- `.git/hooks` and `.git/config` are read-only, since they run commands on the
  host. So `git config`, `git remote` and `git push` are done on the host, and
  the git identity is passed in as `GIT_AUTHOR_*` / `GIT_COMMITTER_*`.
- Volumes: `cargo-target`, `cargo-registry`, `agent-home` (Claude login, via
  `CLAUDE_CONFIG_DIR`), `pgdata`.

## Commands

`just sandbox::...` (host):

- `up`, `down`, `clean` (also deletes volumes), `rebuild`, `status`
- `shell [feature]`
- `agent-feature <feature> [db]`: creates on first use the worktree and branch
  `<feature>`, the database `app_<feature>` (pass `app` to use the shared
  one) and a cargo target dir, then launches `claude` there.
- `agent-feature-clean <feature> [db] [force]`: removes all of it. Without
  `force`, it stops on uncommitted changes and keeps unmerged branches.
- `db-new`, `db-drop`, `db-list`
- `proxy-reload` (after editing the allowlist), `proxy-logs`, `egress-check`
- `doctor`

`just app::...` (anywhere): `build`, `check`, `test`, `lint`, `fmt`,
`migrate`, `ci`, etc.

## Threat model

It protects against:
- reading or writing host files outside the two mounts
- planting git hooks or config that would run on the host
- editing the running sandbox's definition
- reaching hosts that are not on the allowlist

It does not protect against:
- agents touching each other's worktrees or refs
- data leaving through allowed hosts
- domain fronting, since filtering is by `CONNECT` hostname only
- `ANTHROPIC_API_KEY` being visible inside the container
- merged changes (`build.rs`, `.cargo/config.toml`, `.sandbox/`, justfiles)
  that run when you build on the host. Review diffs before merging.

Only HTTP(S) on ports 80/443 gets through. SSH git remotes do not work from
inside.

## Gotchas

- A refused HTTPS request shows as curl `000`, not `403`: squid refuses the
  `CONNECT` before any HTTP response exists.
- `crates.io` (the website) returns 403 to bare curl. Test with
  `index.crates.io/config.json`.
- If a domain is blocked unexpectedly, look for `TCP_DENIED` in
  `proxy-logs`.

## Verification

`just sandbox::egress-check` checks that the allowlist works, that other
domains are refused, and that there is no direct egress, no external DNS and
working internal DNS. Then try a test feature: commit from inside the
container, run `cargo build` (crates go through the proxy), check that
`touch /workspace/.git/hooks/x` fails, and finish with
`agent-feature-clean test-x force`.
