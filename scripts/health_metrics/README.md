# Health Metrics Directory

This directory contains tools originally developed for health metrics (code coverage and binary size), but currently used for other purposes.

## Updated Files Collector

The `get_updated_files.sh` script and the `generate_code_coverage_report/Sources/UpdatedFilesCollector` Swift tool are used to determine which podspecs have been modified in a pull request. This information is used by the `.github/workflows/infra.spec_testing.yml` workflow to run tests only for the affected SDKs.

The file `file_patterns.json` defines the mapping between file paths and SDK names.
