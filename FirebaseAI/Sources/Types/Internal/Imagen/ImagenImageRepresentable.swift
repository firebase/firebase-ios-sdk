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

// TODO(andrewheard): Make this public when the SDK supports Imagen operations that take images as
// input (upscaling / editing).
/// @DeprecationSummary {
///  All Imagen models are deprecated and will shut down as early as June 2026.
///  As a replacement, you can [migrate your apps to use Gemini Image models
///  (the "Nano Banana" models).](https://firebase.google.com/docs/ai-logic/imagen-models-migration)
/// }
@available(
  *,
  deprecated,
  message: "All Imagen models are deprecated and will shut down as early as June 2026. As a replacement, you can migrate your apps to use Gemini Image models (the \"Nano Banana\" models)."
)
protocol ImagenImageRepresentable: Sendable {
  /// Internal representation of the image for use with the Imagen model.
  ///
  /// - Important: Not needed by SDK users.
  var _internalImagenImage: _InternalImagenImage { get }
}
