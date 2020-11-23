/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

import GoogleDataTransport

import os.signpost

/// The test actions to run under the profiler to measure performance of `GDTCORFlatFileStorage.checkForExpirations()` method.
@available(iOS 12.0, *)
class EventCleanupPerfTest {
  static let log = OSLog(subsystem: "GoogleDataTransport-TestApp", category: "EventCleanupPerfTest")

  static func run(completion: @escaping () -> Void) {
    let signpostID = OSSignpostID(log: log)

    os_signpost(.begin, log: log, name: "checkForExpirations", signpostID: signpostID)
    GDTCORFlatFileStorage.sharedInstance().checkForExpirations()

    GDTCORFlatFileStorage.sharedInstance().storageQueue.async {
      os_signpost(.end, log: log, name: "checkForExpirations", signpostID: signpostID)
      completion()
    }
  }

  static func generateTestEvents(count: Int, _ completion: @escaping () -> Void) {
    let signpostID = OSSignpostID(log: log)

    let group = DispatchGroup()

    os_signpost(.begin, log: log, name: "generateTestEvents", signpostID: signpostID)

    _ = (0 ..< count).compactMap { (_) -> GDTCOREvent? in
      group.enter()
      let event = GDTCOREventGenerator.generateEvent(for: .test, qosTier: nil, mappingID: nil)
      GDTCORFlatFileStorage.sharedInstance().store(event) { _, _ in
        group.leave()
      }

      return event
    }

    group.notify(queue: .main) {
      os_signpost(.end, log: log, name: "generateTestEvents", signpostID: signpostID)
      completion()
    }
  }
}
