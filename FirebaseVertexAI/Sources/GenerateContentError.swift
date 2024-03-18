// Copyright 2023 Google LLC
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

/// Errors that occur when generating content from a model.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public enum GenerateContentError: Error {
  /// An error occurred when constructing the prompt. Examine the related error for details.
  case promptImageContentError(underlying: ImageConversionError)

  /// An internal error occurred. See the underlying error for more context.
  case internalError(underlying: Error)

  /// A prompt was blocked. See the response's `promptFeedback.blockReason` for more information.
  case promptBlocked(response: GenerateContentResponse)

  /// A response didn't fully complete. See the `FinishReason` for more information.
  case responseStoppedEarly(reason: FinishReason, response: GenerateContentResponse)

  /// The provided API key is invalid.
  case invalidAPIKey(message: String)

  /// The user's location (region) is not supported by the API.
  ///
  /// See the Google documentation for a
  /// [list of regions](https://ai.google.dev/available_regions#available_regions)
  /// (countries and territories) where the API is available.
  ///
  /// - Important: The API is only available in
  /// [specific regions](https://ai.google.dev/available_regions#available_regions).
  case unsupportedUserLocation
}
