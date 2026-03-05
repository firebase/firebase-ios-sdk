// Copyright 2026 Google LLC
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

/// Configures the sliding window context compression mechanism.
///
/// The context window will be truncated by keeping only a suffix of it.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
public struct SlidingWindow: Sendable {
  /// The session reduction target, i.e., how many tokens we should keep.
  public let targetTokens: Int?

  /// Creates a ``SlidingWindow`` instance.
  ///
  /// - Parameter targetTokens: The target number of tokens to keep in the context window.
  public init(targetTokens: Int? = nil) {
    self.targetTokens = targetTokens
  }
}

/// Enables context window compression to manage the model's context window.
///
/// This mechanism prevents the context from exceeding a given length.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
public struct ContextWindowCompressionConfig: Sendable {
  /// The number of tokens (before running a turn) that triggers the context
  /// window compression.
  public let triggerTokens: Int?

  /// The sliding window compression mechanism.
  public let slidingWindow: SlidingWindow?

  /// Creates a ``ContextWindowCompressionConfig`` instance.
  ///
  /// - Parameters:
  ///   - triggerTokens: The number of tokens that triggers the compression mechanism.
  ///   - slidingWindow: The sliding window compression mechanism to use.
  public init(triggerTokens: Int? = nil, slidingWindow: SlidingWindow? = nil) {
    self.triggerTokens = triggerTokens
    self.slidingWindow = slidingWindow
  }
}
