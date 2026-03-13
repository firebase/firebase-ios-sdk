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
  let bidiSlidingWindow: BidiSlidingWindow

  /// Creates a new ``SlidingWindow`` value.
  ///
  /// - Parameters:
  ///   - targetTokens: The target number of tokens to keep in the context window.
  public init(targetTokens: Int? = nil) {
    self.init(BidiSlidingWindow(targetTokens: targetTokens))
  }

  init(_ slidingWindow: BidiSlidingWindow) {
    self.bidiSlidingWindow = slidingWindow
  }
}

/// Enables context window compression to manage the model's context window.
///
/// This mechanism prevents the context from exceeding a given length.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
public struct ContextWindowCompressionConfig: Sendable {
  let bidiContextWindowCompressionConfig: BidiContextWindowCompressionConfig

  /// Creates a new ``ContextWindowCompressionConfig`` value.
  ///
  /// - Parameters:
  ///   - triggerTokens: The number of tokens that triggers the compression mechanism.
  ///   - slidingWindow: The sliding window compression mechanism to use.
  public init(triggerTokens: Int? = nil, slidingWindow: SlidingWindow? = nil) {
    self.init(
      BidiContextWindowCompressionConfig(
        triggerTokens: triggerTokens,
        slidingWindow: slidingWindow?.bidiSlidingWindow
      )
    )
  }

  init(_ bidiContextWindowCompressionConfig: BidiContextWindowCompressionConfig) {
    self.bidiContextWindowCompressionConfig = bidiContextWindowCompressionConfig
  }
}
