# Contributing to Firebase

Thank you for your interest in contributing and welcome to the Firebase community! <!-- Sparky? -->

This guide describes the many ways to contribute to Firebase and outlines the preferred 
Firebase development workflow.


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

## Reporting a bug
[bug]

## Making a feature request
Feature requests should ideally be clear and concise (i.e. "Add Sign in with Apple support").
If the feature request is more specific, describe it by providing a use case that is not achievable with
existing Firebase APIs and include an API proposal that would make the use case possible. The proposed API
change does not need to be very detailed.

To make a feature request, fill out a new feature request form [here][feature-request].

For large or ambiguous requests, such as significant breaking changes or use cases that require multiple new 
features, consider instead starting a [Pitch][pitch-discussions] to discuss and flush out ideas with the
Firebase community.

## Starting a discussion
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
Please note that changes to public APIs require an internal API review from the Firebase team. Contributions involving changes to existing APIs or new APIs are  

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
tests are an important part

#### Viewing Code Coverage
`⌥⌘U` `Product → Scheme ➞ Edit Scheme`




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
<!-- TODO: link to code of conduct and remind people to be kind and respectful. -->

## License
<!-- TODO: state license and link to LICENSE. -->


<!-- ---------------------------------- -->
<!-- Identifiers, in alphabetical order -->
[bug]: https://github.com/firebase/firebase-ios-sdk/issues/new?assignees=&labels=&template=bug_report.md
[existing issue]: https://github.com/firebase/firebase-ios-sdk/issues
[feature-request]: https://github.com/firebase/firebase-ios-sdk/issues/new?assignees=&labels=type%3A+feature+request&template=feature_request.md
[feature-requests]: https://github.com/firebase/firebase-ios-sdk/issues?q=is%3Aopen+is%3Aissue+label%3A%22type%3A+feature+request%22
[GitHub Help]: https://help.github.com/articles/about-pull-requests/
[good-first-issue]: https://github.com/firebase/firebase-ios-sdk/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22
[Google CLA dashboard]: https://cla.developers.google.com
[help-wanted]: https://github.com/firebase/firebase-ios-sdk/issues?q=is%3Aopen+is%3Aissue+label%3A%22help+wanted%22
[new issue]: https://github.com/firebase/firebase-ios-sdk/issues/new/choose
[pitch-discussions]: https://github.com/firebase/firebase-ios-sdk/discussions/categories/pitches