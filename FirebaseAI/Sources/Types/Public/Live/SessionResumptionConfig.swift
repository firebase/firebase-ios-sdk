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

/// Configuration for the session resumption mechanism.
///
/// When included in the session setup, the server will send
/// ``LiveSessionResumptionUpdate`` messages in the response stream.
@available(watchOS, unavailable)
public struct SessionResumptionConfig: Sendable {
  let bidiSessionResumptionConfig: BidiSessionResumptionConfig

  /// Resumes  a ``SessionResumptionConfig`` instance.
  ///
  /// To start a new session, use ``SessionResumptionConfig/init()`` instead.
  ///
  /// - Parameters:
  ///   - handle: The session resumption handle of the previous session to restore.
  public init(handle: String) {
    self.init(BidiSessionResumptionConfig(handle: handle, transparent: nil))
  }

  /// Creates a new ``SessionResumptionConfig`` instance.
  ///
  /// To resume a previously started session, use ``SessionResumptionConfig/init(handle:)`` instead.
  public init() {
    self.init(BidiSessionResumptionConfig(handle: nil, transparent: nil))
  }

  init(_ bidiSessionResumptionConfig: BidiSessionResumptionConfig) {
    self.bidiSessionResumptionConfig = bidiSessionResumptionConfig
  }
}
