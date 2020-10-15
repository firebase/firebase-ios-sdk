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
  version: "7.0.0",
  pods: [
    Pod("GoogleUtilities", isFirebase: false, podVersion: "7.0.0", releasing: false),
    Pod("GoogleDataTransport", isFirebase: false, podVersion: "8.0.0", releasing: true),

    Pod("FirebaseCoreDiagnostics"),
    Pod("FirebaseCore"),
    Pod("FirebaseInstallations"),
    Pod("FirebaseInstanceID"),
    Pod("GoogleAppMeasurement", isClosedSource: true),
    Pod("FirebaseAnalytics", isClosedSource: true),
    Pod("FirebaseABTesting"),
    Pod("FirebaseAppDistribution", isBeta: true),
    Pod("FirebaseAuth"),
    Pod("FirebaseCrashlytics"),
    Pod("FirebaseDatabase"),
    Pod("FirebaseDynamicLinks"),
    Pod("FirebaseFirestore", allowWarnings: true),
    Pod("FirebaseFirestoreSwift", isBeta: true),
    Pod("FirebaseFunctions"),
    Pod("FirebaseInAppMessaging", isBeta: true),
    Pod("FirebaseMessaging"),
    Pod("FirebasePerformance", isClosedSource: true),
    Pod("FirebaseRemoteConfig"),
    Pod("FirebaseStorage"),
    Pod("FirebaseStorageSwift", isBeta: true),
    Pod("FirebaseMLCommon", isClosedSource: true, isBeta: true),
    Pod("FirebaseMLModelInterpreter", isClosedSource: true, isBeta: true),
    Pod("FirebaseMLVision", isClosedSource: true, isBeta: true),
    Pod("Firebase", allowWarnings: true),
  ]
)

/// Manifest describing the contents of a Firebase release.
public struct Manifest {
  public let version: String
  public let pods: [Pod]
}
