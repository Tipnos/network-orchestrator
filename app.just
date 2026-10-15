# app.just — project commands (build, test, lint, migrate). No sandbox
# awareness: you and the agent run the same `just app::ci`.
# NATS_URL comes from the environment (set by the sandbox).

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

# Everything CI runs, in one command. Both a human before pushing and the
# agent before calling a task "done" should run this rather than guessing
# which checks matter.
ci: fmt-check lint test
    @echo "all checks passed"
