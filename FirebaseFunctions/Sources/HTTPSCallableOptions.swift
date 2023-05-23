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

/// Configuration options for a ``HTTPSCallable`` instance.
@objc(FIRHTTPSCallableOptions) public class HTTPSCallableOptions: NSObject {
  /// Whether or not to protect the callable function with a limited-use App Check token.
  @objc public let requireLimitedUseAppCheckTokens: Bool

  /// Designated initializer.
  /// - Parameter requireLimitedUseAppCheckTokens: A boolean used to decide whether or not to
  /// protect the callable function with a limited use App Check token.
  @objc public init(requireLimitedUseAppCheckTokens: Bool) {
    self.requireLimitedUseAppCheckTokens = requireLimitedUseAppCheckTokens
  }
}
