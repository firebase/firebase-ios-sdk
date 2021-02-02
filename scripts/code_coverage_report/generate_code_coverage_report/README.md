# coverage_report_parser

This is a tool to read test coverages of xcresult bundle and generate a json report. This json
report will be sent to Metrics Service to create a coverage report as a comment in a PR or to update
the coverage database.

## Usage

This is tool will be used for both pull_request and merge. Common flags are shown below.

```
swift run CoverageReportGenerator --presubmit "${REPO}" --commit "${GITHUB_SHA}" --token "${TOKEN}" \
--xcresult-dir "${XCRESULT_DIR}" --log-link "${}" --pull-request-num "${PULL_REQUEST_NUM}" \
--base-commit "${BASE_COMMIT}" --branch "${BRANCH}"
```
Common parameters for both pull_request and merge:
- `presubmit/merge`: A required flag to know if the request is for pull requests or merge.
- `REPO`: A required argument for a repo where coverage data belong.
- `commit`: The current commit sha.
- `token`: A token to access a service account of Metrics Service
- `xcresult-dir`: A directory containing all xcresult bundles.

### Create a report in a pull request

In a workflow, this will run for each pull request update. The command below will generate a report
in a PR. After a workflow of test coverage is done, a new coverage report will be posted on a
comment of a pull request. If such comment has existed, this comment will be overriden by the latest
report.

Since the flag is `presubmit` here, the following options are required for a PR request:
- `log-link`: Log link to unit tests. This is generally a actions/runs/ link in Github Actions.
- `pull-request-num`: A report will be posted in this pull request.
- `base-commit`: The commit sha used to compare the diff of the current`commit`.

An example in a Github Actions workflow:
```
swift run CoverageReportGenerator --presubmit "firebase/firebase-ios-sdk" --commit "${GITHUB_SHA}" \
--token $(gcloud auth print-identity-token) --xcresult-dir "/Users/runner/test/codecoverage" \
--log-link "https://github.com/firebase/firebase-ios-sdk/actions/runs/${GITHUB_RUN_ID}" \
--pull-request-num ${{github.event.pull_request.number}} --base-commit "$base_commit"

```

### Add new coverage data to the storage of Metrics Service

In a workflow, this will run in merge events or postsubmit tests. After each merge, all pod tests
will run to add a new commit and its corresponding coverage data.
```
swift run CoverageReportGenerator --merge "firebase/firebase-ios-sdk" --commit "${GITHUB_SHA}" \
--token $(gcloud auth print-identity-token) --xcresult-dir "/Users/runner/test/codecoverage" \
--log-link "https://github.com/firebase/firebase-ios-sdk/actions/runs/${GITHUB_RUN_ID}" --branch \
"${GITHUB_REF##*/}"
```
- `branch`: this is for merge and the new commit with coverage data will be linked with the branch
in the database of Metrics Service.

### Details

More details in go/firebase-ios-sdk-test-coverage-metrics. Can also run
`swift run CoverageReportGenerator -h` for help info.
