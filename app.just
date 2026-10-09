# app.just — project commands (build, test, lint, migrate). No sandbox
# awareness: you and the agent run the same `just app::ci`.
# DATABASE_URL comes from the environment (set per feature by
# `just sandbox::agent-feature`).

# Compile the project. Fails fast on a type error, same as CI would.
build:
    cargo build

# Optimized build, for when you specifically need release artifacts.
build-release:
    cargo build --release

# Type-check without producing binaries — the quickest way to find compile
# errors while iterating.
check:
    cargo check

# Run the test suite.
test:
    cargo test

# Run a single test (or any substring match on test names).
test-one name:
    cargo test {{name}}

# Format the codebase.
fmt:
    cargo fmt

# Check formatting without changing anything — what CI should run, so a
# human or the agent can confirm `fmt` isn't needed before committing.
fmt-check:
    cargo fmt -- --check

# Lint, treating warnings as errors (matches what CI enforces).
lint:
    cargo clippy --all-targets -- -D warnings

# Run the application.
run *args:
    cargo run {{args}}

# Apply pending database migrations against DATABASE_URL.
migrate:
    sqlx migrate run

# Revert the most recent migration.
migrate-revert:
    sqlx migrate revert

# Regenerate sqlx's offline query cache (.sqlx/), needed after changing a
# query macro so builds succeed without a live database connection.
sqlx-prepare:
    cargo sqlx prepare

# Everything CI runs, in one command. Both a human before pushing and the
# agent before calling a task "done" should run this rather than guessing
# which checks matter.
ci: fmt-check lint test
    @echo "all checks passed"
