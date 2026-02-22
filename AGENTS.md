# MaTool Agent Rules

## Git command execution

- Run Git commands from the project root: `/Users/matsushitakazuya/private/MaTool`.
- Do not use `git -C ...` in this repository because it may fail in this environment.

## Package.resolved rule

- Do not commit `Package.resolved` changes by default.
- Exception: commit only when adding a new package dependency and the lock update is required.
- This applies to all package roots (for example: `Shared/Package.resolved`, `Backend/Package.resolved`).

## Bootstrap execution policy

- Do not execute `Backend/Bootstrap` tests or migration/injector routines in the sandbox.
- In normal development and CI-fix workflows, treat Bootstrap as out of scope unless explicitly instructed by the user.
