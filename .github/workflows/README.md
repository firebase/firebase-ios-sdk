# GitHub Actions Style Guide & Best Practices

This document outlines the architectural patterns, rules, and best practices
for contributing to the `.github/workflows/` directory in the
`firebase-ios-sdk` repository. It expands upon the conventions defined in the
directory's README to ensure consistency, security, and reliability across our
CI/CD pipelines.

## 1. Conceptual Overview

### Namespaced Naming Convention
To organize the large number of workflows in this monorepo, we utilize a
strictly enforced naming convention. This groups files by their domain rather
than their trigger type.

| Namespace | Prefix | Purpose |
| :--- | :--- | :--- |
| **Toolbox** | `_` | Reusable workflows (templates) that define logic. Never run directly. |
| **Infrastructure** | `infra.` | Repo-level health, linters, tooling, and global checks. |
| **Release** | `release.` | Publishing pipelines, staging, and packaging (Zip, SPM, CocoaPods). |
| **Product SDK** | `sdk.` | Product-specific CI pipelines (e.g., `sdk.auth.yml`). |

### The "Toolbox" Strategy (`_*.yml`)
We follow a **"Define Once, Use Everywhere"** philosophy.
*   **Logic lives in `_` files:** Complex logic (e.g., compiling SPM targets,
    running pod lib lint with specific flags, setting up simulators) resides
    in reusable workflows prefixed with `_` (e.g., `_spm.yml`,
    `_cocoapods.yml`).
*   **SDK files are configuration:** Product-specific files (e.g.,
    `sdk.firestore.yml`) should primarily be *consumers* of these tools,
    passing in product names and configuration flags as inputs.
*   **Benefit:** This ensures that if we need to update the Xcode version or
    change how we handle caching, we modify one file (`_spm.yml`), and it
    propagates to all 15+ SDKs immediately.

---

## 2. Workflow Creation Standards (The "Rules")

### Triggers (`on:`)
Define triggers precisely to avoid unnecessary compute usage.

*   **`pull_request`:** Use strict path filtering. Only run workflows if files
    relevant to that specific SDK or tool have changed.
    ```yaml
    on:
      pull_request:
        paths:
        - 'FirebaseAuth/**'
        - '.github/workflows/sdk.auth.yml' # Always include the workflow file itself
        - 'Gemfile*' # Rebuild on infra changes
    ```
*   **`schedule`:** Used for "Nightly" or "Cron" jobs. **Note:** GitHub Cron
    uses UTC. Always comment the target timezone conversion.
    ```yaml
    schedule:
      # Run every day at 11pm (PDT) / 2am (EDT) - cron uses UTC times
      - cron:  '0 6 * * *'
    ```
*   **`workflow_dispatch`:** Always include this to allow manual triggering for
    debugging without pushing empty commits.

### Concurrency
Prevent redundant builds when new commits are pushed to a PR. Use
`cancel-in-progress: true`.

```yaml
concurrency:
    group: ${{ github.workflow }}-${{ github.head_ref || github.ref }}
    cancel-in-progress: true
```

### Permissions (Least Privilege)
Explicitly define permissions at the workflow level. Default to `read` only.

```yaml
permissions:
  contents: read
```
*   *Exception:* `issues: write` or `pull-requests: write` for bot workflows
    (e.g., `infra.danger.yml`).

### Action Pinning (Security)
**Strict Rule:** Third-party actions must be pinned to a **full commit hash**,
not a tag or branch. This prevents supply-chain attacks if a tag is moved to a
malicious commit. Include the version tag as a comment for readability.

**Correct:**
```yaml
uses: actions/checkout@8e8c483db84b4bee98b60c0593521ed34d9990e8 # v6.0.1
```

**Incorrect:**
```yaml
uses: actions/checkout@v6 # DO NOT DO THIS
```

---

## 3. Common Implementation Patterns

### Flakiness Mitigation (`nick-fields/retry`)
Mobile CI is inherently flaky (simulators failing to boot, network timeouts).
Do not use standard `run:` for compilation or testing steps. Use the retry
action.

*   **Timeout:** Set explicit timeouts (usually 15-20m for unit tests, 60m+
    for heavy integration tests).
*   **Wait:** Add a wait time between retries to allow transient system issues
    to resolve.

```yaml
- uses: nick-fields/retry@ce71cc2ab81d554ebbe88c79ab5975992d79ba08 # v3
  with:
    timeout_minutes: 20
    max_attempts: 3
    retry_wait_seconds: 120
    command: scripts/build.sh ...
```

### Environment Setup
Standardize the environment setup to ensure reproducibility.

1.  **Ruby:** Use `ruby/setup-ruby` and our centralized bundler script.
    ```yaml
    - uses: ruby/setup-ruby@... # v1
    - name: Setup Bundler
      run: scripts/setup_bundler.sh
    ```
2.  **Xcode:** Explicitly select the Xcode version.
    ```yaml
    - name: Xcode
      run: sudo xcode-select -s /Applications/Xcode_16.4.app/Contents/Developer
    ```

### Secret Management
Secrets are not automatically passed to reusable workflows. You must pass them
explicitly.

*   **Storage:** Most files (plists, credentials) are encrypted in the repo
    using `gpg`.
*   **Decryption:** Use `scripts/decrypt_gha_secret.sh` and the secret
    passphrase.
*   **Reusable Workflows:** Pass the secret via the `secrets:` block.

**Caller (`sdk.auth.yml`):**
```yaml
jobs:
  quickstart:
    uses: ./.github/workflows/_quickstart.yml
    with:
      product: Authentication
      # ...
    secrets:
      plist_secret: ${{ secrets.GHASecretsGPGPassphrase1 }}
```

### Script Delegation
Avoid writing complex bash logic inside YAML files.
*   **Pattern:** Write a script in `scripts/`, make it executable, and call it.
*   **Reasoning:** Scripts can be linted, tested locally, and don't suffer from
    YAML indentation hell.
*   **Example:** `scripts/pod_lib_lint.rb`, `scripts/build.sh`.

---

## 4. SDK Workflow Template (`sdk.[product].yml`)

When adding a new product (e.g., `sdk.newfeature.yml`), adhere to this
standard structure. It typically consists of four phases: SPM Unit Tests,
Catalyst Tests, Pod Lib Linting, and a Cron job for extended platforms.

```yaml
name: sdk.newfeature

permissions:
  contents: read

on:
  workflow_dispatch:
  pull_request:
    paths:
    - 'FirebaseNewFeature**'
    - '.github/workflows/sdk.newfeature.yml'
    - 'Gemfile*'
  schedule:
    - cron: '0 8 * * *'

concurrency:
    group: ${{ github.workflow }}-${{ github.head_ref || github.ref }}
    cancel-in-progress: true

jobs:
  # 1. SPM Unit Tests (Standard unit tests)
  spm:
    uses: ./.github/workflows/_spm.yml
    with:
      target: NewFeatureUnit

  # 2. Catalyst Tests (Ensure it builds/runs on Mac Catalyst)
  catalyst:
    uses: ./.github/workflows/_catalyst.yml
    with:
      product: FirebaseNewFeature
      target: FirebaseNewFeature-Unit-unit

  # 3. Pod Lib Lint (Verify CocoaPods compatibility)
  pod_lib_lint:
    uses: ./.github/workflows/_cocoapods.yml
    with:
      product: FirebaseNewFeature
      # Optional: buildonly_platforms: tvOS, macOS (if tests are iOS only)

  # 4. Extended Cron Checks (Static frameworks, older OSs, extra platforms)
  newfeature-cron-only:
    needs: pod_lib_lint
    uses: ./.github/workflows/_cocoapods.cron.yml
    with:
      product: FirebaseNewFeature
      platforms: '[ "ios", "tvos", "macos" ]'
      flags: '[ "--use-static-frameworks" ]'
```

---

## 5. Maintenance & Debugging

### Artifact Uploads
Always upload logs and test results when a job fails. This is critical for
debugging CI-only failures. Use the standard condition `if: ${{ failure() }}`.

```yaml
- uses: actions/upload-artifact@b7c566a772e6b6bfb58ed0dc250532a479d7789f # v6.0.0
  if: ${{ failure() }}
  with:
    name: xcodebuild-logs-${{ matrix.platform }}
    path: xcodebuild-*.log
    if-no-files-found: error
```

### Recommended Timeouts
Fail fast to save resources.

| Job Type | Recommended Timeout |
| :--- | :--- |
| **Linting** | 15 minutes |
| **Unit Tests** | 15-20 minutes |
| **Integration Tests** | 30-45 minutes |
| **Archiving** | 20 minutes |

### Global Environment Variables
If a job requires specific behavior for CI (e.g., ignoring warnings that are
valid locally), set `FIREBASE_CI=true` or use product-specific flags (e.g.,
`FIREBASECI_USE_LATEST_GOOGLEAPPMEASUREMENT`).