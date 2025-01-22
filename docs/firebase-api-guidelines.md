# Firebase API Guidelines

This document builds upon the design guidelines provided by [Swift's official
API design guidelines][1] and the [Google Swift Style Guide][2]. It is essential
to be familiar with these resources before proceeding with the API proposal
process.

If Objective-C is required, additionally refer to the [Google Objective-C Style
Guide][3].

## Guidance

### New APIs should be Swift-only

Swift is the preferred language for Apple development, so new Firebase APIs
should be fully optimized for Swift. When designing new APIs, consider whether
they can be implemented in Swift only. If an Objective-C API is required, it
should be carefully considered and justified.

Note that Swift and Objective-C are interoperable, and a module's public
Objective-C API will be exposed to Swift via a generated Swift interface. In
some cases where the public Objective-C API surface is added to, the
corresponding generated Swift interface should be manually refined to be more
idiomatic. Apple provides a [guide][4] for improving such Objective-C API
declarations for Swift.

### Include Swift code samples

It is important for new APIs to be as easy to use in Swift as possible. When
creating a proposal, prioritize Swift code samples to demonstrate the new API's
usage.

### Async API should be written in async/await form

Swift has built-in [support][5] for writing asynchronous code. If a
callback-based API is required, it should be carefully considered and justified.
Callbacks are still useful for capturing work to be done later, like for
example, an event handler like SwiftUI's [`onSubmit`][6] view modifier.

```swift
// ✔ Preferred async/await form.
public func fetchData() async throws -> Data { ... }

// x Pre Swift Structured Concurrency. No longer preferred.
public func fetchData(completion: (Data, any Error) -> Void) { ... }
```

### New APIs should be Sendable

A [Sendable][7] type is one that is thread-safe and can be shared safely across
multiple concurrency contexts. The requirements for conforming to the Sendable
protocol vary depending on the type (class, actor, enum, struct, etc.). Swift 6
introduces strict concurrency checking and enforces Sendable types in
asynchronous code. If applicable, new APIs should be Sendable and designed to be
used in an async context (e.g. `Task`).

### Access Control

New Swift APIs should use the `public` access level over `open`. The `open`
access level allows for subclasses to override the API.

Additionally, new Swift classes should be `final` to prevent clients from
subclassing, unless otherwise justified.

### API Availability

By design, an API may not be available on a given Apple platform. Swift supports
platform-specific compilation and runtime checks.

Code can be conditionally compiled for only iOS by wrapping it with `#if
os(iOS)and #endif`. For more info, refer to [NSHipster's guide][8].

#### Platform Versioning Specification

For code that builds on all platforms but should only be available on select
platforms, use the `@available` declaration attribute discussed in [NSHipster's
guide][9].

Firebase's main distribution channel, Swift Package Manager, only supports a
single minimum supported version for all products. This minimum supported
version will correspond to Crashlytics and Analytics, which historically share a
minimum supported version that is lower than the rest of Firebase. When adding a
new API to the rest of Firebase, refer to the minimum supported versions in the
product's CocoaPods podspec, and declare it on the API's signature via the
[`@available`][9] declaration attribute.

```swift
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
func myNewAPI() { ... }
```

### Constants

In Objective-C, constants were usually defined at the global level. In Swift,
constants can instead be grouped under a case-less enum. The benefit of a
case-less enum over a struct or class is that a case-less enum cannot be
initialized. Additionally, Swift constants do not contain a "k" prefix.

```swift
public enum NetworkConstants {
  public static let httpPostMethod = "POST"
  public static let httpGetMethod = "GET"
}
```

### Minimizing optionals

Unlike Objective-C, Swift handles nullability in a type safe way using
[optionals][10]. While useful, avoid overusing them as they can complicate
the callsite.

### Structs over enums for backwards compatibility {:#structs-enums}

Adding a case to a Swift enum is a breaking change for clients switching
over the enum's cases. Enums should be chosen when they are considered
frozen or very unlikely to be changed (as major version releases occur
about once a year).

An alternative to using enums is to use structs. The following PRs use
structs to model cases similar to how an enum does. One downside to this
approach is that clients switching over a struct do not get a compile
time check ensuring each case is handled.

1. [firebase-ios-sdk/13728][11]
1. [firebase-ios-sdk/13976][12]

### Avoid Any, AnyObject, and NS-prefixed types {:#avoid-any,}

In Swift, `Any` represents an instance of a reference or value type,
while `AnyObject` represents reference types exclusively (making it
similar to `id` in Objective-C). NS-prefixed types like `NSString` or
`NSNumber` are reference types bridged from Objective-C. None of these
should be used in the public Swift API. Using `Any` and `AnyObject` can
make APIs harder to work with due to their lack of type safety and
ambiguousness. NS-prefixed types on the other hand should be swapped
\out for their corresponding Swift value type like `String` for
`NSString`.

For example, if a public API's signature uses a dictionary whose values
should be either a `String` or `Int`, consider modeling this with an
enum or struct rather than `Any`.

```swift
public struct CustomValue {
  public static func string(_ string: String) -> Self { ... }
  public static func integer(_ integer: Int) -> Self { ... }
}

func setValues(_ values: [String: CustomValue]) async throws { ... }
```

### Documentation

New APIs should have corresponding documentation using [Swift-flavored
Markdown][13]. Xcode can generate a documentation block's structure when the
cursor is in the method signature and ⌥ ⌘ / is pressed.

### Naming Conventions

[Swift's official API design guidelines][1] provide an overview to creating
idiomatic Swift API.

#### Optimize for clarity and expressiveness

Choose names that leverage clarity over conciseness. For example, choose
`fetchMetadata()` over `fetch()`.

Avoid using _get_ as a prefix. For example, in Apple's WeatherKit, Apple
[uses][14] `weather(for location: CLLocation)` instead of `getWeather(for
location: CLLocation)`.

#### Consistency with existing Firebase APIs

Consider the precedent set by the existing API that is adjacent to the new API
being added. New APIs should be consistent with the existing Firebase API
surface, and diverge only when justified.

### Errors

If the new API can fail, mark the API as `throws` and create (or add onto) an
existing public [error][15] for the API to throw. Swift provides an `Error`
protocol that can be used to create descriptive errors that can be easily
handled by clients.

### Don't define typedefs

_This guideline only applies when changing public Objective-C API_.

Don't define typedefs as they hide the underlying type in the corresponding
generated Swift API. Instead, use the full type, regardless of how long the
Objective-C API signature becomes.

[1]: https://www.swift.org/documentation/api-design-guidelines/
[2]: https://google.github.io/swift/
[3]: https://google.github.io/styleguide/objcguide.html
[4]: https://developer.apple.com/documentation/swift/improving-objective-c-api-declarations-for-swift
[5]: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/
[6]: https://developer.apple.com/documentation/swiftui/view/onsubmit(of:_:)
[7]: https://developer.apple.com/documentation/swift/sendable
[8]: https://nshipster.com/swift-system-version-checking/
[9]: https://nshipster.com/available/
[10]: https://developer.apple.com/documentation/swift/optional
[11]: https://github.com/firebase/firebase-ios-sdk/pull/13728
[12]: https://github.com/firebase/firebase-ios-sdk/pull/13976
[13]: https://nshipster.com/swift-documentation/
[14]: https://developer.apple.com/documentation/weatherkit/weatherservice/weather(for:)
[15]: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/
