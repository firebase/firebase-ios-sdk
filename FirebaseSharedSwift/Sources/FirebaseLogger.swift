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

public class FirebaseLogger {
  let subsystem: String = "com.google.firebase"

  let category: String

  private lazy var logger: FirebaseInternalLog = {
    if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
      return FirebaseInternalLogger(subsystem: subsystem, category: category)
    } else {
      return OSLog(subsystem: subsystem, category: category)
    }
  }()

  public init(category: String) {
    self.category = category
  }

  public func notice(_ message: String) {
    logger.notice(message)
  }

  public func info(_ message: String) {
    logger.info(message)
  }

  public func debug(_ message: String) {
    logger.debug(message)
  }

  public func warning(_ message: String) {
    logger.warning(message)
  }

  public func error(_ message: String) {
    logger.error(message)
  }

  public func fault(_ message: String) {
    logger.fault(message)
  }
}
