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

/// Request for the client to execute the provided ``functionCalls``.
///
/// The client should return matching ``FunctionResponsePart``, where the
/// ``FunctionResponsePart/functionId`` fields correspond to individual ``FunctionCallPart``s.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
@available(watchOS, unavailable)
public struct LiveServerToolCall: Sendable {
  let serverToolCall: BidiGenerateContentToolCall

  /// A list of ``FunctionCallPart`` to run and return responses for.
  public var functionCalls: [FunctionCallPart]? {
    serverToolCall.functionCalls?.map { FunctionCallPart($0) }
  }

  init(_ serverToolCall: BidiGenerateContentToolCall) {
    self.serverToolCall = serverToolCall
  }
}
