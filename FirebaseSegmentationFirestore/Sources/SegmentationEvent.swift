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

public struct SegmentationEvent {
  static var fis: String?

  public static func register(with events: [String]) {
    if fis != nil {
      fatalError("register can only be called once.")
    }
    Installations.installations().installationID { (fis, error) in
      if let error = error {
        fatalError("FIS failed \(error)")
      }
      guard let iid = fis else {
        fatalError("Null FIS")
      }
      publishRecord(iid, events)
    }
  }

  public static func log(events: [String]) {
    guard let fis = fis else {
      fatalError("register must be called before log.")
    }
    publishRecord(fis, events)
  }

  private static func publishRecord(_ fis: String, _ events: [String]) {
    // TODO: What should the name of the collection be?
    let segmentRef = Firestore.firestore().collection("paultest").document(fis)
    let segment = Segment(iid: fis, labels: events, date: Timestamp())
    do {
      try segmentRef.setData(from: segment)
    } catch {
      fatalError("Encoding Segment failed: \(error)")
    }
  }
}
