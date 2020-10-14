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

/// The manifest contents for a release.
/// Version should be updated every release.
/// The version and releasing fields of the non-Firebase pods should be reviewed every release.
public let shared = Manifest(
  version: "6.99.0",
  pods: [
    Pod("GoogleUtilities", isFirebase: false, podVersion: "6.99.9999", releasing: true),
    Pod("GoogleDataTransport", isFirebase: false, podVersion: "6.999.990", releasing: true),

    Pod("FirebaseCoreDiagnostics"),
    Pod("FirebaseCore"),
    Pod("FirebaseInstallations"),
    Pod("FirebaseInstanceID"),
    Pod("FirebaseAnalytics", isClosedSource: true),
    Pod("FirebaseABTesting"),
    Pod("FirebaseAppDistribution"),
    Pod("FirebaseAuth"),
    Pod("FirebaseCrashlytics"),
    Pod("FirebaseDatabase"),
    Pod("FirebaseDynamicLinks"),
    Pod("FirebaseFirestore"),
    Pod("FirebaseFirestoreSwift"),
    Pod("FirebaseFunctions"),
    Pod("FirebaseInAppMessaging"),
    Pod("FirebaseMessaging"),
    Pod("FirebaseRemoteConfig"),
    Pod("FirebaseStorage"),
    Pod("FirebaseStorageSwift"),
    Pod("Firebase")
  ]
)

/// Manifest describing the contents of a Firebase release.
public struct Manifest {
  public let version: String
  public let pods: [Pod]
}

/// Struct describing Firebase pods to release.
public struct Pod {
  public let name: String
  public let isClosedSource: Bool
  public let isFirebase: Bool
  public let podVersion: String? // non-Firebase pods have their own version
  public let releasing: Bool     // non-Firebase pods may not release

  init(_ name: String,
       isClosedSource: Bool = false,
       isFirebase: Bool = true,
       podVersion: String? = nil,
       releasing: Bool = true) {
    self.name = name
    self.isClosedSource = isClosedSource
    self.isFirebase = isFirebase
    self.podVersion = podVersion
    self.releasing = releasing
  }
}
