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

public let shared = Manifest.init()

/// Struct describing Firebase pods to release.
public struct FirebasePod {
  public let name: String
  public let isClosedSource: Bool

  init(_ name: String, isClosedSource: Bool = false) {
    self.name = name
    self.isClosedSource = isClosedSource
  }
}

/// Struct describing non-Firebase pods to release.
public struct OtherPod {
  public let name: String
  public let version: String
  public let releasing: Bool

  init(_ name: String, _ version: String, releasing: Bool) {
    self.name = name
    self.version = version
    self.releasing = releasing
  }
}

/// Manifest describing the contents of a Firebase release.
/// It should be reviewed and updated for every release and provides the data for release
/// automation.
public struct Manifest {
  public let version: String
  public let firebasePods: [FirebasePod]
  public let otherPods: [OtherPod]

  init() {
    self.version = "7.0.0"
    self.otherPods = [
      OtherPod("GoogleUtilities", "7.0.0", releasing: true),
      OtherPod("GoogleDataTransport", "7.5.0", releasing: true)
    ]
    self.firebasePods = [
      FirebasePod("FirebaseCore"),
      FirebasePod("FirebaseInstallations"),
      FirebasePod("FirebaseInstanceId"),
      FirebasePod("FirebaseAnalytics", isClosedSource: true),
    ]
  }
}
