# sandbox::...  host-side: start the sandbox, launch feature agents.
# app::...      project commands; same for you and the agent, host or sandbox.

mod sandbox
mod app

default:
    @just --list --list-submodules
