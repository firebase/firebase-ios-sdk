// Copyright 2020 Google LLC
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
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseInstallations

@objc public class SegmentationEvent: NSObject {
  static var fis: String?
  static var version = Bundle.main.infoDictionary?["CFBundleShortVersionString"]

  static var operationQueue: OperationQueue = {
    let operation = OperationQueue()
    operation.qualityOfService = .userInitiated
    operation.maxConcurrentOperationCount = 1

    return operation
  }()

  private static func register(with events: [String], targeting: Bool) {
    if fis != nil {
      fatalError("register can only be called once.")
    }
    operationQueue.addOperation {
      Installations.installations().installationID { fis, error in
        if let error = error {
          fatalError("FIS failed \(error)")
        }
        guard let iid = fis else {
          fatalError("Null FIS")
        }
        self.fis = iid
        if let version = self.version {
          log(events: ["SessionStart:\(version)"])
        }
        log(events: events, targeting: targeting)
      }
    }
  }

  // There is only one record in the database per instance for targeting and it is keyed by the fis.
  @objc public static func logForTargeting(events: [String]) {
    log(events: events, targeting: true)
  }

  public static func log(events: [String], targeting: Bool = false) {
    if fis == nil {
      register(with: events, targeting: targeting)
    } else {
      let fis = self.fis!
      operationQueue.addOperation {
        publishRecord(fis, targeting, events)
      }
    }
  }

  @objc public static func log(events: [String]) {
    log(events: events, targeting: false)
  }

  private static func publishRecord(_ fis: String, _ fisKey: Bool, _ events: [String]) {
    // TODO: What should the name of the collection be?

    var segmentRef: DocumentReference
    Firestore.firestore().clearPersistence()
    if fisKey {
      segmentRef = Firestore.firestore().collection("paultest").document(fis)
    } else {
      // auto-generate the document ref.
      segmentRef = Firestore.firestore().collection("paultest").document()
    }
    let segment = Segment(iid: fis, labels: events, date: Timestamp())
    do {
      try segmentRef.setData(from: segment)
    } catch {
      fatalError("Encoding Segment failed: \(error)")
    }
  }
}
