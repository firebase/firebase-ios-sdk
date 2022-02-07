# Headers and Imports

## Introduction

Follow this set of guidelines when creating header files and importing them. The
guidelines are designed to support a wide range of build systems and usage scenarios.

In this document, the term `library` refers to a buildable package. In CocoaPods, it's a CocoaPod.
In Swift Package Manager, it's a library target.

## Header File Types and Locations - For Header File Creators

* *Public Headers* - Headers that define the library's API. They should be located in
  `FirebaseFoo/Sources/Public/FirebaseFoo`. Any additions require a minor version update. Any
  changes or deletions require a major version update.

* *Public Umbrella Header* - A single header that includes the full library's public API located at
  `FirebaseFoo/Sources/Public/FirebaseFoo/FirebaseFoo.h`.

* *Private Headers* - Headers that are available to other libraries in the repo, but are not part
  of the public API. These should be located in `FirebaseFoo/Sources/Private`.
  [Xcode](https://stackoverflow.com/a/8016333). They should be accessed with a repo-relative
  import. For CocoaPods, do not use the `private_headers` attribute. Instead include them in both
  the provider and client's `source_files` attribute.

* *Interop Headers* - A special kind of private header that defines an interface to another library.
  Details in [Firebase Component System docs](Interop/FirebaseComponentSystem.md).

* *Private Umbrella Header* - A single header that includes the library's public API plus any APIs
  provided for other libraries in the repo. Any package manager complexity should be localized to
  this umbrella header.

* *Library Internal Headers* - Headers that are only used by the enclosing library. These headers
  should be located among the source files. [Xcode](https://stackoverflow.com/a/8016333) refers to
  these as "Project Headers".

* *Library C++ Internal Headers* - In CocoaPods, C++ internal headers should not be included
  in the `source_files` attribute. Instead, they should be defined with the `preserve_paths`
  attribute to avoid filename collisions in the generated Xcode workspace. C++ does not assume
  a global header map, so if filenames are qualified at all, it's generally by directory, not a
  filename prefix like in Objective-C.

## Imports - For Header File Consumers

* *Headers within the Library* - Use a repo-relative path for all of the header types above.
  * *Exception* - Public header imports from other public headers should do an unqualified
  import like `#import "publicHeader.h"` to avoid public module collisions.

* *Private Headers from other Libraries* - Import a private umbrella header like
  `FirebaseCore/Internal/FirebaseCoreInternal.h`. For CocoaPods, these files should be
  added to the podspec in the `source_files` attribute like:
```
  s.source_files = [ 'FirebaseFoo/Sources/**/*.[mh]'
                     'Interop/Auth/Public/*.h',
                     'FirebaseCore/Internal/*.h',
                   ]
```

* *Headers from an external dependency* - Do a module import for Swift Package Manager and an
  umbrella header import otherwise, like:
```
#if SWIFT_PACKAGE
@import GTMSessionFetcherCore;
#else
#import <GTMSessionFetcher/GTMSessionFetcher.h>
#endif
```

## Additional Background

Here is some additional detail that should give deeper insight onto the above guidelines.

### Build Systems

We support building with CocoaPods, cmake, internal Google build system, and Swift Package
Manager (in development). Using repo-relative headers is a key enabler since it allows all headers
to be found with a single path specifier no matter what the build system.

#### CocoaPods Build Systems
CocoaPods itself has a range of options that impact the functionality of header imports.

The `use_frameworks!` option enables `@import {module-name}`. CocoaPods creates a directory structure
such that `#import <pod-name/header>` works whether or not frameworks are built.

CocoaPods builds a different directory structure for a `Development Pods` install versus an install
from a published podspec. This can hide errors resulting from header search path pointing outside
of a particular pod's sources.


### "Internal" versus "Private"

"Internal" and "Private" are often used interchangeably since
[Xcode](https://stackoverflow.com/a/8016333) and CocoaPods usage is
inconsistent with expectations of C++ developers. "Private" headers are available to clients
via an explicit import. "Internal" or "Project" headers are only available to their enclosing
library. Many file names in this repo include "Private" or "Internal" do not comply. Always
check the build definition to see how the file is used.

### Public Header Location Explanation

CocoaPods flattens all headers specified in the podspec and makes them available via
`#import "FirebaseFoo/Header.h"`. Swift Package Manager does not flatten. Therefore, the
directory structure described above allows clients to import headers from either package manager
without `#if` checks.
