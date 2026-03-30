// Copyright 2025 Google LLC
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

/// A `safetyAttributes` "prediction" from Imagen.
///
/// @DeprecationSummary {
///  All Imagen models are deprecated and will shut down as early as June 2026.
///  As a replacement, you can [migrate your apps to use Gemini Image models
///  (the "Nano Banana" models).](https://firebase.google.com/docs/ai-logic/imagen-models-migration)
/// }
///
/// This prediction is currently unused by the SDK and is only checked to be valid JSON. This type
/// is currently only used to avoid logging unsupported prediction types.
@available(
  *,
  deprecated,
  message: "All Imagen models are deprecated and will shut down as early as June 2026. As a replacement, you can migrate your apps to use Gemini Image models (the \"Nano Banana\" models)."
)
struct ImagenSafetyAttributes: Decodable {
  let safetyAttributes: JSONObject
}
