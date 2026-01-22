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

/// A logger that reports heartbeats.
public class HeartbeatLogger {
  private let heartbeatController: HeartbeatController
  private let userAgentProvider: () -> String

  public init(appID: String) {
    self.heartbeatController = HeartbeatController(id: appID)
    // TODO: Implement proper user agent generation
    self.userAgentProvider = {
      return "FirebaseCoreLinux/1.0"
    }
  }

  public func log() {
    let userAgent = userAgentProvider()
    heartbeatController.log(userAgent)
  }

  public func headerValue() -> String? {
    let payload = heartbeatController.flush()
    if payload.isEmpty {
      return nil
    }
    return payload.headerValue()
  }
}
