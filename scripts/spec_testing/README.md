# Spec Testing Directory

This directory contains tooling to determine which podspecs have been modified in a pull request. This information is used by the `.github/workflows/infra.spec_testing.yml` workflow to run tests only for the affected SDKs.

## Updated Files Collector

The `get_updated_files.sh` script utilizes the `updated_files_collector/Sources/UpdatedFilesCollector` Swift tool.

The file `file_patterns.json` defines the mapping between file paths and SDK names.
