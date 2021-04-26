# Podspec presubmit test setup

Podspec presubmit test is to help ensure podspec is releasable. 'pod spec lint' will run for SDKs
with sources of

- https://github.com/firebase/SpecsTesting
- https://github.com/firebase/SpecsDev.git
- https://github.com/firebase/SpecsStaging.git
- https://cdn.cocoapods.org/

where [SpecsTesting](https://github.com/firebase/SpecsTesting) is generated from the head of the
master branch of [firebase-ios-sdk repo](https://github.com/firebase/firebase-ios-sdk).

The [prerelease workflow](https://github.com/firebase/firebase-ios-sdk/blob/master/.github/workflows/prerelease.yml#L11-L46)
will update the [SpecsTesting repo](https://github.com/firebase/SpecsTesting) nightly from the
head of the master branch.
In order to let presubmit tests run on the latest podspec repo, [SpecsTesting repo](https://github.com/firebase/SpecsTesting)
will be updated when a PR with changed podspecs is merged.
When this PR is merged, changed podspecs will be `pod repo push`ed to the podspec repo in
[postsubmit tests](https://github.com/firebase/firebase-ios-sdk/blob/master/.github/workflows/prerelease.yml#L48-L94).

Since `pod spec lint` will test podspecs with remote sources. One PR with changes on multiple
podspecs are not encouraged. Changes with multiple podspecs, including their dependencies, might
fail presubmit tests.

## Set up presubmit tests

To set up presubmit tests, we can add a new job in SDK workflows. An example of `FirebaseDatabase`
is shown below.
`github.event.pull_request.merged != true && github.event.action != 'closed'` is to trigger this
job in presubmit.
```
  podspec-presubmit:
    # Don't run on private repo unless it is a PR.
    if: github.repository == 'Firebase/firebase-ios-sdk' && github.event.pull_request.merged != true && github.event.action != 'closed'
    runs-on: macOS-latest
    steps:
    - uses: actions/checkout@v2
    - name: Setup Bundler
      run: scripts/setup_bundler.sh
    - name: Build and test
      run: scripts/third_party/travis/retry.sh pod spec lint FirebaseDatabase.podspec --skip-tests --sources='https://github.com/firebase/SpecsTesting','https://github.com/firebase/SpecsDev.git','https://github.com/firebase/SpecsStaging.git','https://cdn.cocoapods.org/'

```

Once a PR is merged, [`update_SpecsTesting_repo` job](https://github.com/firebase/firebase-ios-sdk/blob/master/.github/workflows/prerelease.yml#L48)
in the [prerelease workflow](https://github.com/firebase/firebase-ios-sdk/blob/master/.github/workflows/prerelease.yml)
will automatically `pod repo push` changed podspecs in postsubmits,
