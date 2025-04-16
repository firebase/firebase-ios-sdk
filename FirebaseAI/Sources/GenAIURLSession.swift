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

/// A namespace providing `URLSession` instances.
enum GenAIURLSession {
  /// The default `URLSession` instance for the SDK; returns `URLSession.shared` by default.
  ///
  /// - Important: On affected simulators (iOS 18.4+, visionOS 2.4+), this returns an ephemeral
  ///   `URLSession` instance as a workaround for a known system bug.
  static let `default` = {
    #if targetEnvironment(simulator)
      // The iOS 18.4 and visionOS 2.4 simulators (included in Xcode 16.3) contain a bug in
      // `URLSession` causing requests to fail. The following workaround, using an ephemeral session
      // resolves the issue. See https://developer.apple.com/forums/thread/777999 for more details.
      //
      // Note: This bug only impacts the simulator, not real devices, and does not impact watchOS
      // or tvOS.
      if #available(iOS 18.4, tvOS 100.0, watchOS 100.0, visionOS 2.4, *) {
        return URLSession(configuration: URLSessionConfiguration.ephemeral)
      }
    #endif // targetEnvironment(simulator)

    return URLSession.shared
  }()
}
