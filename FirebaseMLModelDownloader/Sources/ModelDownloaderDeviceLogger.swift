// Copyright 2021 Google LLC
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
import os

/// On-device logger.
class ModelDownloaderDeviceLogger {
  /// Log event on device.
  static func logEvent(level: OSLogType, category: OSLog, message: StaticString,
                       messageCode: LoggerMessageCode) {
    os_log(message, log: category, type: level)
  }
}

/// Extension to categorize on-device logging.
extension OSLog {
  private static let subsystem: String = {
    let bundleID = Bundle.main.bundleIdentifier ?? ""
    return "com.google.firebaseml.\(bundleID)"
  }()

  /// List of logging categories.
  static let modelDownload = OSLog(subsystem: subsystem, category: "model-download")
  static let analytics = OSLog(subsystem: subsystem, category: "analytics")
}
