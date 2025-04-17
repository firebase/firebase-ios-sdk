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
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public enum GenerateContentError: Error {
  /// An internal error occurred. See the underlying error for more context.
  case internalError(underlying: Error)

  /// An error occurred when constructing the prompt. Examine the related error for details.
  case promptImageContentError(underlying: Error)

  /// A prompt was blocked. See the response's `promptFeedback.blockReason` for more information.
  case promptBlocked(response: GenerateContentResponse)

  /// A response didn't fully complete. See the `FinishReason` for more information.
  case responseStoppedEarly(reason: FinishReason, response: GenerateContentResponse)
}
