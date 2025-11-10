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

/// Client generated response to a `ToolCall` received from the server.
/// Individual `FunctionResponse` objects are matched to the respective
/// `FunctionCall` objects by the `id` field.
///
/// Note that in the unary and server-streaming GenerateContent APIs function
/// calling happens by exchanging the `Content` parts, while in the bidi
/// GenerateContent APIs function calling happens over these dedicated set of
/// messages.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
struct BidiGenerateContentToolResponse: Encodable {
  /// The response to the function calls.
  let functionResponses: [FunctionResponse]?
}
