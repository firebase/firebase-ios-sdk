# Unreleased
- [fixed] Resolved a decoding error for citations without a `uri` and added
  support for decoding `title` fields, which were previously ignored. (#13518)

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
