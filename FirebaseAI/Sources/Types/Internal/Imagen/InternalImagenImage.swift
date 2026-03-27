// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// Internal representation of an image for the Imagen model.
///
/// @DeprecationSummary {
///  All Imagen models are deprecated and will shut down as early as June 2026.
///  As a replacement, you can [migrate your apps to use Gemini Image models
///  (the "Nano Banana" models).](https://firebase.google.com/docs/ai-logic/imagen-models-migration)
/// }
///
/// - Important: For internal use by types conforming to ``ImagenImageRepresentable``; all
/// properties are `internal` and are not needed by SDK users.
///
/// TODO(andrewheard): Make this public when the SDK supports Imagen operations that take images as
/// input (upscaling / editing).
@available(
  *,
  deprecated,
  message: "All Imagen models are deprecated and will shut down as early as June 2026. As a replacement, you can migrate your apps to use Gemini Image models (the \"Nano Banana\" models)."
)
struct _InternalImagenImage {
  let mimeType: String
  let bytesBase64Encoded: String?
  let gcsURI: String?
}
