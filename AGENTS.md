# MaTool Agent Rules

## Git command execution

- Run Git commands from the project root: `/Users/matsushitakazuya/private/MaTool`.
- Do not use `git -C ...` in this repository because it may fail in this environment.
- Before any branch/commit/PR operation, read and follow [$matool-git](/Users/matsushitakazuya/private/MaTool/.codex/skills/matool-git/SKILL.md).
- Before any build/test/run operation, read and follow [$matool-build-test](/Users/matsushitakazuya/private/MaTool/.codex/skills/matool-build-test/SKILL.md).

## Runtime policy (summary)

- After iOSApp work, launch iOSApp on Simulator for verification.
- When working on both iOSApp and Backend:
  - Push `backend/<topic>` branch first.
  - Use API base URL `dev-XXX` for iOSApp launch verification (`XXX` must match `<topic>`).
  - Do not commit this temporary API URL change.
  - If this temporary change was pushed by mistake, revert only that part before creating PR.
- When working on Backend only:
  - Run locally by default.
  - Push only when explicitly instructed.

## Package.resolved rule

- Do not commit `Package.resolved` changes by default.
- Exception: commit only when adding a new package dependency and the lock update is required.
- This applies to all package roots (for example: `Shared/Package.resolved`, `Backend/Package.resolved`).

## Bootstrap execution policy

- Do not execute `Backend/Bootstrap` tests or migration/injector routines in the sandbox.
- In normal development and CI-fix workflows, treat Bootstrap as out of scope unless explicitly instructed by the user.
