# 11.13.0
- [feature] Initial release of the Firebase AI SDK (`FirebaseAI`). This SDK
  replaces the previous Vertex AI in Firebase SDK (`FirebaseVertexAI`). This new
  SDK adds **public preview** support for the Gemini Developer API, including
  support for its free tier offering. To get started, import the `FirebaseAI`
  module and use the top-level `FirebaseAI` class.
- [fixed] Fixed `ModalityTokenCount` decoding when the `tokenCount` field is
  omitted; this occurs when the count is 0. (#14745)
