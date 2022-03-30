# Contributing to Firebase

Thank you for your interest in contributing and welcome to the
Firebase community! 🔥

This guide describes the many ways to contribute to Firebase and
outlines the preferred workflow for Firebase development.

## Contents

* [Reporting a bug](#reporting-a-bug)
* [Making a feature request](#making-a-feature-request)
* [Starting a discussion](#starting-a-discussion)
* [Contributing code](#contributing-code)

- [Development Guide](#development-guide) <!-- List intentionally starts dash -->
    <!-- * [Touring the codebase](#touring-the-codebase) -->
  * [Getting started](#getting-started)
  * [Developing](#developing)
  * [Debugging](#debugging)
  * [Testing](#testing)
  * [Opening a pull request](#opening-a-pull-request)

* [Contributor License Agreement](#contributor-license-agreement)
* [Code of Conduct](#code-of-conduct)
* [License](#license)

----
<!-- Ways to contribute -->

## [Reporting a bug][bug]

To report a bug, fill out a new issue [here][bug]. The pre-populated form
should be filled out accordingly to provide others with useful information
regarding the discovered bug. In most cases, a [minimal reproducible
example] is very helpful in allowing us to quickly reproduce the bug and
work on a fix.

## [Making a feature request][feature-request]

Feature requests should ideally be clear and concise (i.e. _Add Sign in with
Apple support_). If the feature request is more specific, describe it by
providing a use case that is not achievable with existing Firebase APIs and
include an API proposal that would make the use case possible.
The proposed API change does not need to be very detailed.

To make a feature request, fill out a new feature request
form [here][feature-request].

For large or ambiguous requests, such as significant breaking changes or use
cases that require multiple new features, consider instead starting a
[Pitch][pitch-discussions] to discuss and flush out ideas with the Firebase
community.

## [Starting a discussion][new-discussion]

We are using [GitHub discussions][discussions-docs] as a collaborative space
where developers can discuss questions and proposals regarding Firebase. For
large proposals, start a [Pitch][pitch-discussions] to discuss
ideas with the community.

View the [Firebase discussions][discussions] or start one
[here][new-discussion].

## Contributing code

Before starting work on a contribution, it's important to allow the Firebase
community an opportunity to discuss your proposal. First, check to see if your
proposal has appeared in an [existing issue]'s discussion. If it has
not, create a [new issue] and use it to describe and explain your idea. The
Firebase team is happy to provide feedback and advice for how to best
implement your proposal.

> ### Need some inspiration?
>
> Check out issues marked as:
>
> <!-- > TODO: Add good first issue label & contributing project board. -->
> * [`help wanted`][help-wanted]
> * [`type: feature request`][feature-requests]
>
> Additionally, have a look at the [Roadmap] to see Firebase's
> longer term goals. There are many opportunities to get involved!

### API Review

Please note that changes or additions to public APIs require an internal API
review from the Firebase team. Contributions involving such changes will
require additional time to allow for an internal API review to be scheduled and
thoroughly conducted. We appreciate your patience while we review your amazing
contributions!

### Breaking Changes

Firebase's release schedule is designed to reduce the amount of breaking
changes that developers have to deal  with. Ideally, breaking changes should
be avoided when making a contribution.

### Using GitHub pull requests

All submissions, including submissions by project members, require review. We
use GitHub pull requests for this purpose. Refer to [GitHub Help] for
more information on using pull requests. If you're ready to open a pull request,
check that you have completed all of the steps outlined in
the [Opening a pull request](#opening-a-pull-request) section.

----
<!-- Development Guide -->

## Development Guide

The majority of the remaining portion of this guide is dedicated to detailing
the preferred workflow for Firebase development.

<!-- ### Touring the codebase -->
<!-- TODO: Provide a graphic of key areas of the codebase. -->

### Getting started

To develop Firebase software, **install**:

* [Xcode] (v12.2 or later) (for Googlers, visit [go/xcode](go/xcode)) to
  download.
* <details>
  <summary>Code styling tools: <b>clang-format</b> & <b>mint</b></summary>

   <!-- The above line is intentionally left blank. -->
   Firebase use's a style script that requires [clang-format] and [mint].

   To install [clang-format] and [mint] using [Homebrew]:

    ```console
    brew install clang-format@14
    brew install mint
    ```

  </details>

<details>
<summary><b>Next</b>, clone the Firebase repo.</summary>

<!-- The above line is intentionally left blank. -->
* Clone via [HTTPS][github-clone-https]

  ```console
  git clone https://github.com/firebase/firebase-ios-sdk.git
  ```

* Or via [SSH][github-clone-ssh]

  ```console
  git clone git@github.com:firebase/firebase-ios-sdk.git
  ```

</details>
<br> <!-- This new line is for styling purposes. -->

Once the necessary tools have been installed and the project has been cloned,
continue on to the preferred
[development workflow](#developing).

### Developing

The workflow for library development is different from application
development. For Firebase development, we develop using the same tools we
use to distribute Firebase. Instructions for developing with
[Swift Package Manager](#swift-package-manager) and [CocoaPods](#cocoapods)
are as follows:

#### **[Swift Package Manager]**

[Swift Package Manager] is built into Xcode and makes it simple to develop
projects with multiple dependencies.

To develop using SwiftPM, open the `Package.swift` file in your cloned
Firebase copy (or `open Package.swift` from the command line) and select a
library scheme to build and develop that library.

To learn more about running tests with Swift Package Manager, visit the
[Testing](#testing) section.

<!-- SwiftPM troubleshooting -->
<!-- TODO: Common issues and fixes like resolve depencies & reset cache. -->

#### **[CocoaPods]**

[CocoaPods] is another popular dependency manager used in Apple development.
Firebase supports development with CocoaPods 1.10.0 (or later). If you choose to
develop using CocoaPods, it's recommend to use
[`cocoapods-generate`][cocoapods-generate], a plugin that generates a
[workspace] from a [podspec]. This plugin allows you to quickly generate a
development workspace using any library's podspec. All of the podspecs for
Firebase's libraries are located in the repo's root directory.

#### Installation

* **[CocoaPods]**
  <!-- This line is intentionally left blank. -->
  To check if your machine has CocoaPods installed, run `pod --version` in
  terminal. If the command fails with a `command not found` error, then you'll
  need to install CocoaPods.

  To install, please refer to CocoaPods's [Getting Started][cocoapods-install] guide.

* **[cocoapods-generate]**
  <!-- This line is intentionally left blank. -->
  Please see [cocoapods-generate] for instructions on how to install.

#### Developing with CocoaPods

With **CocoaPods** and **cocoapods-generate** installed, the `pod gen` command
makes it easy to develop specific Firebase libraries.

```console
pod gen Firebase{name here}.podspec --local-sources=./ --auto-open --platforms=ios
```

* If the CocoaPods cache is out of date, you may need to run
  `pod repo update` before the `pod gen` command.
* Set the `--platforms` option to `macos` or `tvos` to develop on those
   platforms. Since 10.2, Xcode does not properly handle multi-platform
   CocoaPods workspaces.

<details>
<summary><i>Developing for Mac Catalyst?</i></summary>

<!-- The above line is intentionally left blank. -->
To develop for [Mac Catalyst], there are a few additional steps to configure
the project.

1. Run `pod gen {name here}.podspec --local-sources=./ --auto-open --platforms=ios`
2. Check the **Mac** box in the host app's **Build Settings**
3. Sign the host app in the **Signing & Capabilities** tab
4. Navigate to **Pods** in the **Project Manager**
5. Add **Signing** to the **host app** and **unit test** targets
6. Select the **Unit-unit** scheme
7. **Run** it to build and test

**Alternatively**, disable signing in each target:

1. Go to **Build Settings** tab
2. Click **+**
3. Select **Add User-Defined Setting**
4. Add `CODE_SIGNING_REQUIRED` setting with a value of `NO`

</details>
<br> <!-- This new line is for styling purposes. -->

<!-- #### **Sample Apps** -->

#### **Style Guide**

This code in this repo is styled in accordance to `clang-format` conventions.

#### Styling your code

The [./scripts/style.sh] script makes it easy to style your
code during development. Running the style script on the folder you worked in is
the most efficient way to only format your changes changes.

For example, if your changes were done in `FirebaseStorage/Sources/`:

```console
./scripts/style.sh FirebaseStorage/Sources/
```

Alternatively, the script can be work on branch names or filenames.

```console
 ./scripts/style.sh fix-storage-bug
```

```console
./scripts/style.sh FirebaseStorage/Sources/FIRStorage.m
```

<details>
<summary>More details on using the <b>style.sh</b> script</summary>

<!-- The above line is intentionally left blank. -->

```bash
# Usage:
# ./scripts/style.sh [branch-name | filenames]
#
# With no arguments, formats all eligible files in the repo
# Pass a branch name to format all eligible files changed since that branch
# Pass a specific file or directory name to format just files found there
#
# Commonly
# ./scripts/style.sh your_branch
```

</details>

If your PR is failing CI due to style issues please use
the style script accordingly. If the style script is not working, ensure you
have installed the necessary code styling tools outlined in the
[Getting Started](#getting-started) section.

#### Apple development style guides and resources

Refer to the following resources when writing Swift or Objective-C code.

* Swift
  * [Google's Swift Style Guide][google-swift-style]
  * [Swift's API Design Guidelines][swift-api-design-guide]
* Objective-C
  * [Google's Objective-C Style Guide][google-objc-style]
  * [Apple's Coding Guidelines for Cocoa][coding-guidelines-for-cocoa]

#### **An example Git workflow**

This is a general overview of what the Git workflow may look like, from start to
finish, when contributing code to Firebase.
The below snippet is purely for reference purposes and is used to demonstarate
what the workflow may look like, from start to finish.
<details>
<summary>View the workflow</summary>

<!-- The above line is intentionally left blank. -->
For developers without write access, you'll need to create a fork of Firebase
instead of a branch. Learn more about forking a repo [here][github-forks].

```console
# Update your local master
git checkout master
git pull

# Create a development branch
git checkout -b my_feature_or_bug_fix

# Code, commit, repeat
git commit -m "a helpful commit message"

# Push your local branch to the remote
git push --set-upstream origin my_feature_or_bug_fix

# Open a pull request on github.com

# Resolve review feedback on opened PR
git commit -m "implemented suggestion"
git push

# Once your PR has been reviewed and all feedback addressed, it
# will be approved and merged by a project member. 🎉
```

</details>
<br> <!-- This new line is for styling purposes. -->

### Debugging

Xcode ships with many debugging tools. Learn more about debugging in
Xcode by watching [WWDC sessions][wwdc-sessions] about debugging and
viewing the [documentation][xcode-debugging].

### Testing

Tests are an essential part to building Firebase. Many of the tests
for Firebase run as part of our continous integration (CI) setup with
[GitHub Actions].

* _Fixing a bug?_ Add a test to catch potential regressions in
  the future.
* _Adding a new feature?_ Add tests to test the new or
  modified APIs. In addition, highlight the new API by providing
  snippets of how it is used in the API's corresponding issue or
  PR. These snippets will be linked to the release notes so other
  developers can see how the API is used. If more context is
  required to demonstrate the API, reach out to a project member
  about creating an example project to do so.

Oftentimes, tests can be useful in understanding how a particular API works.
Keep this in mind while adding tests as they can serve as an additional tool for
demonstrating how an API should be used.

_Using [Swift Package Manager](#swift-package-manager)?_

1. To enable schemes for [testing](#testing): run `./scripts/setup_spm_tests.sh`
2. Then in Xcode, choose a scheme to build a library or run a test suite.
3. Choose a target platform by selecting the run destination along with
   the scheme.

> _At this time, not all test schemes are configured to run when using_
_Swift Package Manager._

Once a [development workspace](developing) has been set up and a testing scheme
selected, tests can be run by clicking the "play" arrow in the project
navigation bar or by using the `⌘U` keyboard shortcut.

<!-- #### Unit Tests -->
<!-- TODO: Provide resources for model Swift & ObjC unit tests. -->

<!-- #### Integration Tests -->
<!-- TODO: Provide resources for model Swift & ObjC integration tests. -->

<!-- #### Swift API Build Tests -->
<!-- TODO: Provide resources for model Swift API build tests. -->

#### Viewing Code Coverage

When creating tests, it's helpful to verify that certain codepaths are indeed
getting tested. Xcode has a built-in code coverage tool that makes it easy to
know what codepaths are run. To enable it, navigate
from `Product → Scheme ➞ Edit Scheme` or use the `⌥⌘U` keyboard shortcut
to show the current testing scheme. Enable code coverage by selecting
the **Options** tab and checking the **Code Coverage** box.

<!-- TODO: Insert GIF of enabling code coverage. -->

The Firebase repo contains a code coverage report tool. To learn more, view
the [code coverage report documentation][code-cov-report-docs].

### Opening a pull request

Before opening a pull request (PR), ensure that your contribution meets the
following criteria:

1. A descriptive PR description has been written that explains the
   purpose of this contribution.
2. The committed code has been styled in accordance with this repo's style
   guidelines.
3. A CHANGELOG has been updated to reflect the PR's associated changes.
4. Unit and/or integration tests have been added or updatd to test and
   validate the contribution's changes.
5. Refer to the
   [Contributor License Agreement](#contributor-license-agreement) section below
   to sign a CLA.

<!-- TODO: Add picture of opening a PR. -->

<!-- #### Addressing Continuous Integration (CI) failures -->

<!-- #### Resolving feedback -->

----

## Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement (CLA). You (or your employer) retain the copyright to your
contribution, this simply gives us permission to use and redistribute your
contributions as part of the project. Head over to the
[Google CLA dashboard][google-cla-dashboard]
to sign a new one or to see your current agreements on file.

You generally only need to submit a CLA once, so if you've already submitted one
(even if it was for a different project), you probably don't need to do it
again.

## Code of Conduct

We aim to foster a community of learning and kindness at Firebase. By
participating, you are expected to have reviewed and agreed to
our [Code of Conduct].

## License

For more information about the license used for this project, please refer to
[LICENSE].

<!-- ---------------------------------- -->
<!-- Identifiers, in alphabetical order -->
[bug]: https://github.com/firebase/firebase-ios-sdk/issues/new?assignees=&labels=&template=bug_report.md
[clang-format]: https://clang.llvm.org/docs/ClangFormat.html
[CocoaPods]: https://cocoapods.org/about
[cocoapods-generate]: https://github.com/square/cocoapods-generate
[cocoapods-install]: https://guides.cocoapods.org/using/getting-started.html#getting-started
[coding-guidelines-for-cocoa]: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CodingGuidelines/CodingGuidelines.html
[discussions]: https://github.com/firebase/firebase-ios-sdk/discussions
[discussions-docs]: https://docs.github.com/en/discussions
[existing issue]: https://github.com/firebase/firebase-ios-sdk/issues
[feature-request]: https://github.com/firebase/firebase-ios-sdk/issues/new?assignees=&labels=type%3A+feature+request&template=feature_request.md
[feature-requests]: https://github.com/firebase/firebase-ios-sdk/issues?q=is%3Aopen+is%3Aissue+label%3A%22type%3A+feature+request%22
[GitHub Actions]: https://docs.github.com/en/actions
[GitHub Help]: https://help.github.com/articles/about-pull-requests/
[github-clone-https]: https://docs.github.com/en/get-started/getting-started-with-git/about-remote-repositories#cloning-with-https-urls
[github-clone-ssh]: https://docs.github.com/en/get-started/getting-started-with-git/about-remote-repositories#cloning-with-ssh-urls
[github-forks]: https://docs.github.com/en/get-started/quickstart/fork-a-repo
[good-first-issue]: https://github.com/firebase/firebase-ios-sdk/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22
[google-cla-dashboard]: https://cla.developers.google.com
[google-objc-style]: https://google.github.io/styleguide/objcguide.html
[google-swift-style]: https://google.github.io/swift/
[help-wanted]: https://github.com/firebase/firebase-ios-sdk/issues?q=is%3Aopen+is%3Aissue+label%3A%22help+wanted%22
[Homebrew]: https://brew.sh/
[new-discussion]: https://github.com/firebase/firebase-ios-sdk/discussions/new
[new issue]: https://github.com/firebase/firebase-ios-sdk/issues/new/choose
[Mac Catalyst]: https://developer.apple.com/mac-catalyst/
[minimal reproducible example]: https://stackoverflow.com/help/minimal-reproducible-example
[mint]: https://github.com/yonaskolb/Mint
[pitch-discussions]: https://github.com/firebase/firebase-ios-sdk/discussions/categories/pitches
[podspec]: https://guides.cocoapods.org/making/specs-and-specs-repo.html
[swift-api-design-guide]: https://swift.org/documentation/api-design-guidelines/
[Swift Package Manager]: https://swift.org/package-manager/
[workspace]: https://developer.apple.com/library/archive/featuredarticles/XcodeConcepts/Concept-Workspace.html
[wwdc-sessions]: https://developer.apple.com/videos/
[Xcode]: https://developer.apple.com/xcode/
[xcode-debugging]: https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/debugging_with_xcode/chapters/debugging_tools.html

<!-- File/Code Identifiers, in alphabetical order -->
[Code of Conduct]: ./CODE_OF_CONDUCT.md
[code-cov-report-docs]: scripts/code_coverage_report/README.md
[LICENSE]: ./LICENSE
[Roadmap]: ./ROADMAP.md
[./scripts/style.sh]: ./scripts/style.sh
