# Kokoro CI jobs and testing scripts

Firebase uses a Google-internal continuous integration tool called "Kokoro"
(a.k.a "internal CI") for running majority of its open source tests. This
directory contains the external part of kokoro test job configurations (the
actual job definitions live in Google's internal monorepo) and the shell
scripts that act as entry points to execute the actual tests.

## Kokoro job structure

Each job name should follow the format `product_target_method_xcodeversion.cfg`
(i.e. `Core_macOS_xcodebuild_Xcode10_1.cfg`). The Xcode version may be omitted
for builds that do not target Apple platforms. Presubmit jobs should go into
the `pull_request` directory and should be marked as `PRESUBMIT_GITHUB`.
Postsubmit jobs should be marked as `CONTINUOUS_INTEGRATION`. Each job can specify
the build script it invokes and additional environment variables that kokoro
should provide. For a full list of capabilities, see the kokoro docs
(Google-internal).

## Adding a kokoro job

Each cfg file in the prod kokoro configuration directory (or any subdirectories)
is a distinct job. To add a new job, submit a CL with your new cfg file in
google3 and then submit a PR to this repository with a corresponding test script
in this directory. See the google-internal Firebase iOS docs for more details.
