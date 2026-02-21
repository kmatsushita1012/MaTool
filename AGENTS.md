# MaTool Agent Rules

## Git command execution

- Run Git commands from the project root: `/Users/matsushitakazuya/private/MaTool`.
- Do not use `git -C ...` in this repository because it may fail in this environment.

## Package.resolved rule

- Do not commit `Package.resolved` changes by default.
- Exception: commit only when adding a new package dependency and the lock update is required.
- This applies to all package roots (for example: `Shared/Package.resolved`, `Backend/Package.resolved`).
