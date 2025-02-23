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

/// An error that occurs when image generation fails due to all generated images being blocked.
///
/// The images may have been blocked due to the specified ``ImagenSafetyFilterLevel``, the
/// ``ImagenPersonFilterLevel``, or filtering included in the model. These filter levels may be
/// adjusted in your ``ImagenSafetySettings``. See the [Responsible AI and usage guidelines for
/// Imagen](https://cloud.google.com/vertex-ai/generative-ai/docs/image/responsible-ai-imagen)
/// for more details.
public struct ImagenImagesBlockedError: Error {
  /// The reason that all generated images were blocked (filtered out).
  let message: String
}

// MARK: - CustomNSError Conformance

extension ImagenImagesBlockedError: CustomNSError {
  public static var errorDomain: String {
    return Constants.Imagen.errorDomain
  }

  public var errorCode: Int {
    return Constants.Imagen.ErrorCode.imagesBlocked.rawValue
  }

  public var errorUserInfo: [String: Any] {
    return [NSLocalizedDescriptionKey: message]
  }
}
