# FoundationModelsFake

> [!IMPORTANT]
> `FoundationModelsFake` is a fake implementation of Apple's
> [Foundation Models](https://developer.apple.com/documentation/foundationmodels)
> framework. It supports development and testing where the real framework isn't
> available, such as on Linux. Its behavior can differ from the real framework.
> Don't ship it in production apps, and test your app against the official
> Foundation Models framework before release.

This package lets `GeminiLanguageModel` build and run its tests on Linux. It
mirrors the public API of Apple's framework closely enough that the Gemini
sources compile against either one.

## Using the fake

`GeminiLanguageModel/Package.swift` depends on this package through its
`FoundationModelsFake` trait. When the trait is enabled, SwiftPM also defines a
`FoundationModelsFake` compilation condition, which the Gemini sources check:

```swift
#if compiler(>=6.4) && (FoundationModelsFake || canImport(FoundationModels))
  #if FoundationModelsFake
    import FoundationModelsFake
  #else
    import FoundationModels
  #endif
#endif
```

| Where | How to enable the trait |
| :--- | :--- |
| Linux | It's on by default. |
| macOS command line | `swift build --traits FoundationModelsFake` or `swift test --traits FoundationModelsFake` |
| Xcode project or workspace | Enable the trait on the package dependency in the Package Dependencies view. |
| Cross-compiling for Linux from macOS | Pass `--traits FoundationModelsFake`, because the default is chosen by the machine that runs SwiftPM. |

With the trait off, SwiftPM neither fetches nor builds this package.

To run the fake's own tests, run `swift test` in this directory. These are unit
tests; the fake's full behavior-comparison suite is maintained separately.

## Differences from Apple's framework

- **Removed types:** `PrivateCloudComputeLanguageModel`, `OCRTool`,
  `BarcodeReaderTool`, the obsolete `SystemLanguageModel.Adapter` API, and the
  feedback API (`LanguageModelFeedback` and
  `LanguageModelSession.logFeedbackAttachment`).
- **Deprecated APIs are omitted,** such as
  `LanguageModelSession.GenerationError`, `Transcript.StructuredSegment.source`,
  and `GenerationOptions.sampling`.
- **`SystemLanguageModel` is always unavailable.** Its availability is
  `.unavailable(.deviceNotEligible)`, and responding throws
  `SystemLanguageModel.Error.assetsUnavailable`. Pass a model, such as
  `GeminiLanguageModel`, when you create a session.
- **Swift versions:** below Swift 6.4, the fake compiles to an empty module,
  like Xcode 26 SDKs, which lack the iOS 27 `LanguageModel` API. The iOS 27.2
  API, such as `Transcript.DataEntry`, needs Swift 6.4.2, like Xcode 27.2.
- **Availability:** public declarations carry the same `@available` attributes
  as Apple's, so code that uses the fake on Apple platforms is checked the same
  way. Availability checking is disabled inside the fake itself.
- **Images on Linux:** image attachments are backed by URLs, because Linux has
  no CoreGraphics or ImageIO, and their embedded EXIF orientation isn't read.
  Linux also gets small shims for `UTType` and `CGImagePropertyOrientation`,
  which cover only the types the fake needs.
- **Image attachments** compare by identity, not by pixels. A `cgImage` that
  can't be loaded, such as one from a remote URL, is a transparent 1×1
  placeholder.
- **Transcript JSON** uses the same format as Apple's, on purpose, so that
  transcripts can be exchanged with the real framework. Images backed by URLs
  are written as their URL (`file:` URLs are embedded) instead of being
  re-encoded, and remote URLs are never fetched.
- **Decoded structured content** isn't `==` to the content it was encoded from,
  because decoding loses the explicit key order. Their JSON is the same.
- **Messages:** error and description strings are the fake's own, so don't
  match on their text.
