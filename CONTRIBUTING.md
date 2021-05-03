# Contributing to Firebase

Thank you for your interest in contributing and welcome to the Firebase community! <!-- Sparky? -->

This guide describes the many ways to contribute to Firebase and outlines the preferred 
workflow for Firebase development.


## Contents
* [Reporting a bug](#reporting-a-bug)
* [Making a feature request](#making-a-feature-request)
* [Starting a discussion](#starting-a-discussion)
* [Contributing code](#contributing-code)
- [Development Guide](#development-guide)
    * [Touring the codebase](#touring-the-codebase)
    * [Getting started](#getting-started)
    * [Developing](#developing)
    * [Debugging](#debugging)
    * [Testing](#testing)
    * [Opening a Pull Request](#opening-a-pull-request)
* [Contributor License Agreement](#contributor-license-agreement)
* [Code of Conduct](#code-of-conduct)
* [License](#license)

----
<!-- Ways to contribute -->

## [Reporting a bug][bug]
To report a bug, fill out a new issue [here][bug]. The pre-populated form should be filled out accordingly to
provide others with useful information regarding the discovered bug. In most cases, a [minimal reproducible
example] is very helpful in allowing us to quickly reproduce the bug and work on a fix. New issues that include
instructions on how to reproduce or provide a link to a simple project that reproduces the bug will likely be
addressed much sooner.

## [Making a feature request][feature-request]
Feature requests should ideally be clear and concise (i.e. "Add Sign in with Apple support").
If the feature request is more specific, describe it by providing a use case that is not achievable with
existing Firebase APIs and include an API proposal that would make the use case possible. The proposed API
change does not need to be very detailed.

To make a feature request, fill out a new feature request form [here][feature-request].

For large or ambiguous requests, such as significant breaking changes or use cases that require multiple new 
features, consider instead starting a [Pitch][pitch-discussions] to discuss and flush out ideas with the
Firebase community.

## [Starting a discussion][new-discussion]
We are using [GitHub discussions][discussions-docs] as a collaborative space where developers can discuss
questions and proposals regarding Firebase. For large proposals, start a [Pitch][pitch-discussions] to discuss
ideas with the community.

View the [Firebase discussions][discussions] or start one [here][new-discussion].

## Contributing code
Before starting work on a contribution, it's important to allow the Firebase community an opportunity to discuss
your proposal. First, check to see if your proposal has appeared in an [existing issue]'s discussion. If it has
not, create a [new issue] and use it to describe and explain your idea. The Firebase team is happy to provide
feedback and advice for how to best implement your proposal.

> ### Need some inspiration?
>
> Check out issues marked as  [`good first issue`][good-first-issue],  [`help wanted`][help-wanted], or
> [`type: feature request`][feature-requests].
> 
> Additionally, have a look at [ROADMAP.md](./ROADMAP.md) to see Firebase's longer term goals. There are many
> opportunities to get invovled!

### API Review
Please note that changes or additions to public APIs require an internal API review from the Firebase team. Contributions involving such changes will require additional time to allow for an internal API review to be scheduled and thoroughly conducted. We appreciate your patience while we review your amazing contributions!

### Breaking Changes
Firebase's release schedule is designed to reduce the amount of breaking changes that developers have to deal  with. Ideally, breaking changes should be avoided when making a contribution.

### Using GitHub pull requests
All submissions, including submissions by project members, require review. We use GitHub pull requests for 
this purpose. Refer to [GitHub Help] for more information on using pull requests.

----
<!-- Development Guide -->

## Development Guide
The majority of the remaining portion of this guide is dedicated to detailing the preferred workflow for Firebase
development.

### Touring the codebase
<!-- Provide visual tour of key areas of the codebase. -->

### Getting started


### Developing
Can depend on package manager

#### **Swift Package Manager**
provide reasoning as to why cocoapods , mention limitations
link to swift package manager in swift docs

- common issues and fixes

#### **CocoaPods**
provide reasoning as to why cocoapods 
#### Installation instructions
Check if you have it. Else: 

#### **Style Guide**
google swift? swift docs. google objc guide

#### **An example git workflow**


### Debugging


### Testing
Tests are an essential part to building successful software. Many of the tests for Firebase run as part of our continous intengration (CI) setup with [GitHub Actions]. _Fixing a bug?_ Add a test to catch potential regressions in the future. _Adding a new feature?_ Add tests to test the new or modified APIs.

Oftentimes, tests can be useful in understanding how a particular class works. Keep this in mind while adding tests as they can serve as an additional tool for demonstrating how an API should be used.

#### Unit Tests

#### Integration Tests

#### Viewing Code Coverage
When creating tests, it's helpful to verify that certain codepaths are indeed getting tested. Xcode has a built-in
code coverage tool that makes it easy to know what codepaths are run. To enable it, navigate from 
`Product → Scheme ➞ Edit Scheme` or use the `⌥⌘U` keyboard shortcut to show the current testing scheme. Enable
code coverage by selecting the _Options_ tab and checking the _Code Coverage_ box.

<!-- TODO: Insert picture of enabling code coverage. -->




### Opening a Pull Request
Before opening a pull request (PR), ensure that your contribution meets the following criteria:
1. A descriptive PR description has been written that explains the purpose of this contribution.
2. The committed code has been styled in accordance with this repo's style guidelines.
3. A CHANGELOG has been updated to reflect the PR's associated changes. 
4. Unit and/or integration tests have been added or updatd to test and validate the contribution's changes.


<!-- TODO: add picture of opening a PR -->

#### Signing the CLA

#### Addressing Continuous Integration (CI) failures

#### Resolving feedback



----

## Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement (CLA). You (or your employer) retain the copyright to your contribution,
this simply gives us permission to use and redistribute your contributions as
part of the project. Head over to the [Google CLA dashboard] to sign a new one or to see your current agreements on file.

You generally only need to submit a CLA once, so if you've already submitted one
(even if it was for a different project), you probably don't need to do it
again.

## Code of Conduct
We aim to foster a community of learning and kindness at Firebase. By participating, you are expected to have reviewed and agreed to
our [CODE_OF_CONDUCT].

## License
For more information about the license used for this project, please refer to [LICENSE].


<!-- ---------------------------------- -->
<!-- Identifiers, in alphabetical order -->
[bug]: https://github.com/firebase/firebase-ios-sdk/issues/new?assignees=&labels=&template=bug_report.md
[discussions]: https://github.com/firebase/firebase-ios-sdk/discussions
[discussions-docs]: https://docs.github.com/en/discussions
[existing issue]: https://github.com/firebase/firebase-ios-sdk/issues
[feature-request]: https://github.com/firebase/firebase-ios-sdk/issues/new?assignees=&labels=type%3A+feature+request&template=feature_request.md
[feature-requests]: https://github.com/firebase/firebase-ios-sdk/issues?q=is%3Aopen+is%3Aissue+label%3A%22type%3A+feature+request%22
[GitHub Actions]: https://docs.github.com/en/actions
[GitHub Help]: https://help.github.com/articles/about-pull-requests/
[good-first-issue]: https://github.com/firebase/firebase-ios-sdk/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22
[Google CLA dashboard]: https://cla.developers.google.com
[help-wanted]: https://github.com/firebase/firebase-ios-sdk/issues?q=is%3Aopen+is%3Aissue+label%3A%22help+wanted%22
[new-discussion]: https://github.com/firebase/firebase-ios-sdk/discussions/new
[new issue]: https://github.com/firebase/firebase-ios-sdk/issues/new/choose
[minimal reproducible example]: https://stackoverflow.com/help/minimal-reproducible-example
[pitch-discussions]: https://github.com/firebase/firebase-ios-sdk/discussions/categories/pitches

<!-- File/Code Identifiers, in alphabetical order -->
[LICENSE]: ./LICENSE
[CODE_OF_CONDUCT]: ./CODE_OF_CONDUCT.md