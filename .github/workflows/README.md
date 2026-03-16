# GitHub Actions Workflow Naming Conventions

This document outlines the naming conventions for GitHub Actions workflows within
this repository. Adhering to these conventions helps maintain clarity and
consistency for maintainers and automated systems.

The workflows are categorized into four groups, identified by their file name
prefixes.

## 1. Reusable Workflows (`_*.yml`)

**Pattern:** `_*.yml`

Files prefixed with an underscore (`_`) are modular workflows intended to be
called by other workflows (using `workflow_call`). They encapsulate common
build steps or testing logic to reduce duplication.

*   **Example:** `_build.yml` (Generic build logic used by multiple SDKs)

## 2. Infrastructure Workflows (`infra.*.yml`)

**Pattern:** `infra.<task>.yml`

Workflows in this category handle general CI/CD infrastructure tasks. They are
not specific to a single SDK but support the overall repository health,
compliance, and tooling.

*   **Example:** `infra.check.yml` (Runs repo-wide style and quality checks)

## 3. Release Workflows (`release.*.yml`)

**Pattern:** `release.<package_manager>.[method].yml`

These workflows manage the building and testing of SDK releases. They
typically handle interactions with package managers (CocoaPods, SPM) or generate
release artifacts (Zip).

*   **Example:** `release.cocoapods.yml` (Manages CocoaPods release testing)

## 4. SDK-Specific Workflows (`sdk.*.yml`)

**Pattern:** `sdk.<product>[.suffix].yml`

These workflows are dedicated to building and testing specific Firebase SDKs.

*   **Basic:** `sdk.<product>.yml` (e.g., `sdk.auth.yml`) - Standard CI for the SDK.
*   **Nightly:** `sdk.<product>.nightly.yml` - Scheduled, resource-intensive tests.
*   **Integration:** `sdk.<product>.integration.yml` - Integration-specific test suites.
