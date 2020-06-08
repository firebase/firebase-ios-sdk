# Headers and Imports

## Introduction

Follow this set of guidelines when creating header files and importing them. The
guidelines are designed to support a wide range of build systems and usage scenarios.

In this document, the term `library` refers to a buildable package. In CocoaPods, it's a CocoaPod.
In Swift Package Manager, it's a library target.

## Header File Types and Locations

* *Public Headers* - Headers that define the library's API. They should be located in
  `FirebaseFoo/Sources/Public`. Any additions require a minor version update. Any changes or
  deletions require a major version update.

* *Public Umbrella Header* - A single header that includes the full library's public API located at
  `FirebaseFoo/Sources/Public/FirebaseFoo.h`. This header should be included in
   [Firebase.h](CoreOnly/Sources/Firebase.h).

* *Library Internal Headers* - Headers that are only used by the enclosing library. These headers
  should be located among the source files. [Xcode](https://stackoverflow.com/a/8016333) refers to
  these as "Project Headers".

* *Private Headers* - Headers that are available to other libraries in the repo, but are not part
  of the public API. These should be located in `FirebaseFoo/Sources/Private`.
  [Xcode](https://stackoverflow.com/a/8016333) and CocoaPods refer to these as "Private Headers".
  Note that we are deprecating the usage of CocoaPods `private_headers` and should instead
  publish them with `preserve_paths` and access them with a repo-relative import.

## Imports

* *Headers within the Library* - Use a repo-relative path. The one exception is
  that public header imports from other public headers should do an unqualified
  import like `import "publicHeader.h"` to avoid colliding with the public module import.

* *Headers within the Repo* - Import an umbrella header like
  `FirebaseCore/Sources/Private/FirebaseCoreInternal.h`. Any package manager
  complexity should be localized to the internal umbrella.

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

### "Internal" versus "Private"

"Internal" and "Private" are often used interchangeably since
[Xcode](https://stackoverflow.com/a/8016333) and CocoaPods usage is
inconsistent with expectations of C++ developers. "Private" headers are available to clients
via an explicit import. "Internal" or "Project" headers are only available to their enclosing
library. Many file names in this repo include "Private" or "Internal" do not comply. Always
check the build definition to see how the file is used.
