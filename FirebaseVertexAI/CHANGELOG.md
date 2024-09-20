# Unreleased
- [changed] **Breaking Change**: The `HarmCategory` enum is no longer nested
  inside the `SafetySetting` struct and the `unspecified` case has been
  removed. (#13686)

# 11.3.0
- [added] Added `Decodable` conformance for `FunctionResponse`. (#13606)

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
  [control generated output](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/control-generated-output)
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
