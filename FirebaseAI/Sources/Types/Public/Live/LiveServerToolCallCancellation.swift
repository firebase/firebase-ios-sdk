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

/// Notification for the client to cancel a previous function call from ``LiveServerToolCall``.
///
/// The client does not need to send ``FunctionResponsePart``s for the cancelled
/// ``FunctionCallPart``s.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
public struct LiveServerToolCallCancellation: Sendable {
  let serverToolCallCancellation: BidiGenerateContentToolCallCancellation
  /// A list of function ids matching the ``FunctionCallPart/functionId`` provided in a previous
  /// ``LiveServerToolCall``, where only the provided ids should be cancelled.
  public var ids: [String]? { serverToolCallCancellation.ids }

  init(_ serverToolCallCancellation: BidiGenerateContentToolCallCancellation) {
    self.serverToolCallCancellation = serverToolCallCancellation
  }
}
