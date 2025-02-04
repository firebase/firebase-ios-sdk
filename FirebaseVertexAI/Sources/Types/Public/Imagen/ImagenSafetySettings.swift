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

/// Settings for controlling the aggressiveness of filtering out sensitive content.
///
/// See the [Responsible AI and usage
/// guidelines](https://cloud.google.com/vertex-ai/generative-ai/docs/image/responsible-ai-imagen#config-safety-filters)
/// for more details.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ImagenSafetySettings {
  let safetyFilterLevel: ImagenSafetyFilterLevel?
  let personFilterLevel: ImagenPersonFilterLevel?

  /// Initializes safety settings for the Imagen model.
  ///
  /// - Parameters:
  ///   - safetyFilterLevel: A filter level controlling how aggressively to filter out sensitive
  ///   content from generated images.
  ///   - personFilterLevel: A filter level controlling whether generation of images containing
  ///   people or faces is allowed.
  public init(safetyFilterLevel: ImagenSafetyFilterLevel? = nil,
              personFilterLevel: ImagenPersonFilterLevel? = nil) {
    self.safetyFilterLevel = safetyFilterLevel
    self.personFilterLevel = personFilterLevel
  }
}
