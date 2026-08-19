# Firebase Apple repo commands

This project includes commands that are too long and complicated to properly
maintain in a bash script, or that have unique option/flag constraints that
are better represented in a swift project.

## Available Commands

- `build`: Build the integration test app for a given SDK.
- `build-for-testing`: Build the integration test app and tests without running.
- `test`: Run integration tests for a given SDK.
- `decrypt`: Decrypt secret files for a test run.

```sh
./scripts/repo.sh --help
./scripts/repo.sh test --help
```
