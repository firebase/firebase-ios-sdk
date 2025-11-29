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

protocol FirebaseInternalLog {
  func notice(_ message: String)

  func info(_ message: String)

  func debug(_ message: String)

  func warning(_ message: String)

  func error(_ message: String)

  func fault(_ message: String)
}

extension OSLog: FirebaseInternalLog {
  func notice(_ message: String) {
    os_log("%s", log: self, type: .default, message)
  }

  func info(_ message: String) {
    os_log("%s", log: self, type: .info, message)
  }

  func debug(_ message: String) {
    os_log("%s", log: self, type: .debug, message)
  }

  func warning(_ message: String) {
    os_log("%s", log: self, type: .default, message)
  }

  func error(_ message: String) {
    os_log("%s", log: self, type: .error, message)
  }

  func fault(_ message: String) {
    os_log("%s", log: self, type: .fault, message)
  }
}

@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
class FirebaseInternalLogger: FirebaseInternalLog {
  private let logger: Logger

  required init(subsystem: String, category: String) {
    logger = Logger(subsystem: subsystem, category: category)
  }

  func notice(_ message: String) {
    logger.notice("\(message)")
  }

  func info(_ message: String) {
    logger.info("\(message)")
  }

  func debug(_ message: String) {
    logger.debug("\(message)")
  }

  func warning(_ message: String) {
    logger.warning("\(message)")
  }

  func error(_ message: String) {
    logger.error("\(message)")
  }

  func fault(_ message: String) {
    logger.fault("\(message)")
  }
}
