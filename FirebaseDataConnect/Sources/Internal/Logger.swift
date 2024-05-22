// Copyright 2024 Google LLC
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
import OSLog

class FirebaseOSLog {
  let subsystem: String = "com.google.firebase"
  let category: String
  let osLog: OSLog

  init(category: String) {
    self.category = category
    osLog = OSLog(subsystem: subsystem, category: category)
  }

  func notice(_ message: String) {
    if #available(iOS 14.0, *) {
      Logger(subsystem: subsystem, category: category).notice("\(message)")
    } else {
      os_log("%s", log: osLog, type: .default, message)
    }
  }

  func info(_ message: String) {
    if #available(iOS 14.0, *) {
      Logger(subsystem: subsystem, category: category).info("\(message)")
    } else {
      os_log("%s", log: osLog, type: .info, message)
    }
  }

  func debug(_ message: String) {
    if #available(iOS 14.0, *) {
      Logger(subsystem: subsystem, category: category).debug("\(message)")
    } else {
      os_log("%s", log: osLog, type: .debug, message)
    }
  }

  func warning(_ message: String) {
    if #available(iOS 14.0, *) {
      Logger(subsystem: subsystem, category: category).warning("\(message)")
    } else {
      // os_log has no equivalent warning type
      os_log("%s", log: osLog, type: .default, message)
    }
  }

  func error(_ message: String) {
    if #available(iOS 14.0, *) {
      Logger(subsystem: subsystem, category: category).error("\(message)")
    } else {
      // os_log has no equivalent warning type
      os_log("%s", log: osLog, type: .error, message)
    }
  }

  func fault(_ message: String) {
    if #available(iOS 14.0, *) {
      Logger(subsystem: subsystem, category: category).fault("\(message)")
    } else {
      os_log("%s", log: osLog, type: .fault, message)
    }
  }
}

extension FirebaseOSLog {
  static let dataConnect = FirebaseOSLog(category: "DataConnect")
}
