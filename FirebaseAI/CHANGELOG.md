# Unreleased
- [fixed] Fixed various links in the Live API doc comments not mapping correctly.
- [fixed] Fixed minor translation issue for nanosecond conversion when receiving
  `LiveServerGoingAwayNotice`. (#15410)

# 12.4.0
- [feature] Added support for the URL context tool, which allows the model to access content
  from provided public web URLs to inform and enhance its responses. (#15221)
- [changed] Using Firebase AI Logic with the Gemini Developer API is now Generally Available (GA).
- [changed] Using Firebase AI Logic with the Imagen generation APIs is now Generally Available (GA).
- [feature] Added support for the Live API, which allows bidirectional
  communication with the model in realtime.

  To get started with the Live API, see the Firebase docs on
  [Bidirectional streaming using the Gemini Live API](https://firebase.google.com/docs/ai-logic/live-api).
  (#15309)

# 12.3.0
- [feature] Added support for the Code Execution tool, which enables the model
  to generate and run code to perform complex tasks like solving mathematical
  equations or visualizing data. (#15280)
- [fixed] Fixed a decoding error when generating images with the
  `gemini-2.5-flash-image-preview` model using `generateContentStream` or
  `sendMessageStream` with the Gemini Developer API. (#15262)

# 12.2.0
- [feature] Added support for returning thought summaries, which are synthesized
  versions of a model's internal reasoning process. (#15096)
- [feature] Added support for limited-use tokens with Firebase App Check.
  These limited-use tokens are required for an upcoming optional feature called
  _replay protection_. We recommend
  [enabling the usage of limited-use tokens](https://firebase.google.com/docs/ai-logic/app-check)
  now so that when replay protection becomes available, you can enable it sooner
  because more of your users will be on versions of your app that send limited-use tokens.
  (#15099)

# 12.0.0
- [feature] Added support for Grounding with Google Search. (#15014)
- [removed] Removed `CountTokensResponse.totalBillableCharacters` which was
  deprecated in 11.15.0. Use `totalTokens` instead. (#15056)

# 11.15.0
- [fixed] Fixed `Sendable` warnings introduced in the Xcode 26 beta. (#14947)
- [added] Added support for setting `title` in string, number and array `Schema`
  types. (#14971)
- [added] Added support for configuring the "thinking" budget when using Gemini
  2.5 series models. (#14909)
- [changed] Deprecated `CountTokensResponse.totalBillableCharacters`; use
  `totalTokens` instead. Gemini 2.0 series models and newer are always billed by
  token count. (#14934)

# 11.13.0
- [feature] Initial release of the Firebase AI Logic SDK (`FirebaseAI`). This
  SDK *replaces* the previous Vertex AI in Firebase SDK (`FirebaseVertexAI`) to
  accommodate the evolving set of supported features and services.
  - The new Firebase AI Logic SDK provides **preview** support for the Gemini
    Developer API, including its free tier offering.
  - Using the Firebase AI Logic SDK with the Vertex AI Gemini API is still
    generally available (GA).

  To start using the new SDK, import the `FirebaseAI` module and use the
  top-level `FirebaseAI` class. See details in the [migration guide
  ](https://firebase.google.com/docs/vertex-ai/migrate-to-latest-sdk).
- [fixed] Fixed `ModalityTokenCount` decoding when the `tokenCount` field is
  omitted; this occurs when the count is 0. (#14745)
- [fixed] Fixed `Candidate` decoding when `SafetyRating` values are missing a
  category or probability; this may occur when using Gemini for image
  generation. (#14817)

# 11.12.0
- [added] **Public Preview**: Added support for specifying response modalities
  in `GenerationConfig`. This includes **public experimental** support for image
  generation using Gemini 2.0 Flash (`gemini-2.0-flash-exp`). (#14658)
  <br /><br />
  Note: This feature is in Public Preview and relies on experimental models,
  which means that it is not subject to any SLA or deprecation policy and could
  change in backwards-incompatible ways.
- [added] Added support for more `Schema` fields: `minItems`/`maxItems` (array
  size limits), `title` (schema name), `minimum`/`maximum` (numeric ranges),
  `anyOf` (select from sub-schemas), and `propertyOrdering` (JSON key order). (#14647)
- [fixed] Fixed an issue where network requests would fail in the iOS 18.4
  simulator due to a `URLSession` bug introduced in Xcode 16.3. (#14677)

# 11.11.0
- [added] Emits a warning when attempting to use an incompatible model with
  `GenerativeModel` or `ImagenModel`. (#14610)

# 11.10.0
- [feature] The Vertex AI SDK no longer requires `@preconcurrency` when imported in Swift 6.
- [feature] The Vertex AI Sample App now includes an image generation example.
- [changed] The Vertex AI Sample App is now part of the
  [quickstart-ios repo](https://github.com/firebase/quickstart-ios/tree/main/vertexai).
- [changed] The `role` in system instructions is now ignored; no code changes
  are required. (#14558)

# 11.9.0
- [feature] **Public Preview**: Added support for
  [generating images](https://firebase.google.com/docs/vertex-ai/generate-images-imagen?platform=ios)
  using the Imagen 3 models.
  <br /><br />
  Note: This feature is in Public Preview, which means that it is not subject to
  any SLA or deprecation policy and could change in backwards-incompatible ways.
- [feature] Added support for modality-based token count. (#14406)

# 11.6.0
- [changed] The token counts from `GenerativeModel.countTokens(...)` now include
  tokens from the schema for JSON output and function calling; reported token
  counts will now be higher if using these features.

# 11.5.0
- [fixed] Fixed an issue where `VertexAI.vertexAI(app: app1)` and
  `VertexAI.vertexAI(app: app2)` would return the same instance if their
  `location` was the same, including the default `us-central1`. (#14007)
- [changed] Removed `format: "double"` in `Schema.double()` since
  double-precision accuracy isn't enforced by the model; continue using the
  Swift `Double` type when decoding data produced with this schema. (#13990)

# 11.4.0
- [feature] Vertex AI in Firebase is now Generally Available (GA) and can be
  used in production apps. (#13725)
  <br /><br />
  Use the Vertex AI in Firebase library to call the Vertex AI Gemini API
  directly from your app. This client library is built specifically for use with
  Swift apps, offering security options against unauthorized clients as well as
  integrations with other Firebase services.
  <br /><br />
  Note: Vertex AI in Firebase is currently only available in Swift Package
  Manager and CocoaPods. Stay tuned for the next release for the Zip and
  Carthage distributions.
  <br /><br />
  - If you're new to this library, visit the
    [getting started guide](http://firebase.google.com/docs/vertex-ai/get-started?platform=ios).
  - If you used the preview version of the library, visit the
    [migration guide](https://firebase.google.com/docs/vertex-ai/migrate-to-ga?platform=ios)
    to learn about some important updates.
- [changed] **Breaking Change**: The `HarmCategory` enum is no longer nested
  inside the `SafetySetting` struct and the `unspecified` case has been
  removed. (#13686)
- [changed] **Breaking Change**: The `BlockThreshold` enum in `SafetySetting`
  has been renamed to `HarmBlockThreshold`. (#13696)
- [changed] **Breaking Change**: The `unspecified` case has been removed from
  the `FinishReason`, `BlockReason` and `HarmProbability` enums; this scenario
  is now handled by the existing `unknown` case. (#13699)
- [changed] **Breaking Change**: The property `citationSources` of
  `CitationMetadata` has been renamed to `citations`. (#13702)
- [changed] **Breaking Change**: The initializer for `Schema` is now internal;
  use the new type methods `Schema.string(...)`, `Schema.object(...)`, etc.,
  instead. (#13852)
- [changed] **Breaking Change**: The initializer for `FunctionDeclaration` now
  accepts an array of *optional* parameters instead of a list of *required*
  parameters; if a parameter is not listed as optional it is assumed to be
  required. (#13616)
- [changed] **Breaking Change**: `CountTokensResponse.totalBillableCharacters`
  is now optional (`Int?`); it may be `null` in cases such as when a
  `GenerateContentRequest` contains only images or other non-text content.
  (#13721)
- [changed] **Breaking Change**: The `ImageConversionError` enum is no longer
  public; image conversion errors are still reported as
  `GenerateContentError.promptImageContentError`. (#13735)
- [changed] **Breaking Change**: The `CountTokensError` enum has been removed;
  errors occurring in `GenerativeModel.countTokens(...)` are now thrown directly
  instead of being wrapped in a `CountTokensError.internalError`. (#13736)
- [changed] **Breaking Change**: The enum `ModelContent.Part` has been replaced
  with a protocol named `Part` to avoid future breaking changes with new part
  types. The new types `TextPart` and `FunctionCallPart` may be received when
  generating content; additionally the types `InlineDataPart`, `FileDataPart`
  and `FunctionResponsePart` may be provided as input. (#13767)
- [changed] **Breaking Change**: All initializers for `ModelContent` now require
  the label `parts: `. (#13832)
- [changed] **Breaking Change**: `HarmCategory`, `HarmProbability`, and
  `FinishReason` are now structs instead of enums types and the `unknown` cases
  have been removed; in a `switch` statement, use the `default:` case to cover
  unknown or unhandled values. (#13728, #13854, #13860)
- [changed] **Breaking Change**: The `Tool` initializer is now internal; use the
  new type method `functionDeclarations(_:)` to create a `Tool` for function
  calling. (#13873)
- [changed] **Breaking Change**: The `FunctionCallingConfig` initializer and
  `Mode` enum are now internal; use one of the new type methods `auto()`,
  `any(allowedFunctionNames:)`, or `none()` to create a config. (#13873)
- [changed] **Breaking Change**: The `CandidateResponse` type is now named
  `Candidate`. (#13897)
- [changed] **Breaking Change**: The minimum deployment target for the SDK is
  now macOS 12.0; all other platform minimums remain the same at iOS 15.0,
  macCatalyst 15.0, tvOS 15.0, and watchOS 8.0. (#13903)
- [changed] **Breaking Change**: All of the public properties of
  `GenerationConfig` are now `internal`; they all remain configurable in the
  initializer. (#13904)
- [changed] The default request timeout is now 180 seconds instead of the
  platform-default value of 60 seconds for a `URLRequest`; this timeout may
  still be customized in `RequestOptions`. (#13722)
- [changed] The response from `GenerativeModel.countTokens(...)` now includes
  `systemInstruction`, `tools` and `generationConfig` in the `totalTokens` and
  `totalBillableCharacters` counts, where applicable. (#13813)
- [added] Added a new `HarmCategory` `.civicIntegrity` for filtering content
  that may be used to harm civic integrity. (#13728)
- [added] Added `probabilityScore`, `severity` and `severityScore` in
  `SafetyRating` to provide more fine-grained detail on blocked responses.
  (#13875)
- [added] Added a new `HarmBlockThreshold` `.off`, which turns off the safety
  filter. (#13863)
- [added] Added an optional `HarmBlockMethod` parameter `method` in
  `SafetySetting` that configures whether responses are blocked based on the
  `probability` and/or `severity` of content being in a `HarmCategory`. (#13876)
- [added] Added new `FinishReason` values `.blocklist`, `.prohibitedContent`,
  `.spii` and `.malformedFunctionCall` that may be reported. (#13860)
- [added] Added new `BlockReason` values `.blocklist` and `.prohibitedContent`
  that may be reported when a prompt is blocked. (#13861)
- [added] Added the `PromptFeedback` property `blockReasonMessage` that *may* be
  provided alongside the `blockReason`. (#13891)
- [added] Added an optional `publicationDate` property that *may* be provided in
  `Citation`. (#13893)
- [added] Added `presencePenalty` and `frequencyPenalty` parameters to
  `GenerationConfig`. (#13899)

# 11.3.0
- [added] Added `Decodable` conformance for `FunctionResponse`. (#13606)
- [changed] **Breaking Change**: Reverted refactor of `GenerativeModel` and
  `Chat` as Swift actors (#13545) introduced in 11.2; The methods
  `generateContentStream`, `startChat` and `sendMessageStream` no longer need to
  be called with `await`. (#13703)

# 11.2.0
- [fixed] Resolved a decoding error for citations without a `uri` and added
  support for decoding `title` fields, which were previously ignored. (#13518)
- [changed] **Breaking Change**: The methods for starting streaming requests
  (`generateContentStream` and `sendMessageStream`) are now throwing and
  asynchronous and must be called with `try await`. (#13545, #13573)
- [changed] **Breaking Change**: Creating a chat instance (`startChat`) is now
  asynchronous and must be called with `await`. (#13545)
- [changed] **Breaking Change**: The source image in the
  `ImageConversionError.couldNotConvertToJPEG` error case is now an enum value
  instead of the `Any` type. (#13575)
- [added] Added support for specifying a JSON `responseSchema` in
  `GenerationConfig`; see
  [control generated output](https://firebase.google.com/docs/vertex-ai/structured-output?platform=ios)
  for more details. (#13576)

# 10.29.0
- [feature] Added community support for watchOS. (#13215)

# 10.28.0
- [changed] Removed uses of the `gemini-1.5-flash-preview-0514` model in docs
  and samples. Developers should now use the auto-updated versions,
  `gemini-1.5-pro` or `gemini-1.5-flash`, or a specific stable version; see
  [available model names](https://firebase.google.com/docs/vertex-ai/gemini-models#available-model-names)
  for more details. (#13099)
- [feature] Added community support for tvOS and visionOS. (#13090, #13092)

# 10.27.0
- [changed] Removed uses of the `gemini-1.5-pro-preview-0409` model in docs and
  samples. Developers should now use `gemini-1.5-pro-preview-0514` or
  `gemini-1.5-flash-preview-0514`; see
  [available model names](https://firebase.google.com/docs/vertex-ai/gemini-models#available-model-names)
  for more details. (#12979)
- [changed] Logged additional details when required APIs for Vertex AI are
  not enabled or response payloads when requests fail. (#13007, #13009)

# 10.26.0
- [feature] Initial release of the Vertex AI for Firebase SDK (public preview).
  Learn how to
  [get started](https://firebase.google.com/docs/vertex-ai/get-started?platform=ios)
  with the SDK in your app.
