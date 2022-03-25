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
/// The array should be ordered so that any pod's dependencies precede it in the list.
public let shared = Manifest(
  version: "8.15.0",
  pods: [
    Pod("FirebaseSharedSwift"),
    Pod("FirebaseCoreDiagnostics", zip: true),
    Pod("FirebaseCore", zip: true),
    Pod("FirebaseInstallations", zip: true),
    Pod("GoogleAppMeasurement", isClosedSource: true),
    Pod("FirebaseAnalytics", isClosedSource: true, zip: true),
    Pod("FirebaseAnalyticsSwift", isBeta: true),
    Pod("FirebaseABTesting", zip: true),
    Pod("FirebaseAppCheck", isBeta: true, zip: true),
    Pod("FirebaseRemoteConfig", zip: true),
    Pod("FirebaseRemoteConfigSwift", isBeta: true),
    Pod("FirebaseAppDistribution", isBeta: true, platforms: ["ios"], zip: true),
    Pod("FirebaseAuth", zip: true),
    Pod("FirebaseCrashlytics", zip: true),
    Pod("FirebaseDatabase", zip: true),
    Pod("FirebaseDatabaseSwift", isBeta: true),
    Pod("FirebaseDynamicLinks", platforms: ["ios"], zip: true),
    Pod("FirebaseFirestore", allowWarnings: true, zip: true),
    Pod("FirebaseFirestoreSwift", isBeta: true),
    Pod("FirebaseFunctions", zip: true),
    Pod("FirebaseFunctionsSwift", isBeta: true),
    Pod("FirebaseInAppMessaging", isBeta: true, platforms: ["ios"], zip: true),
    Pod("FirebaseInAppMessagingSwift", isBeta: true, platforms: ["ios"]),
    Pod("FirebaseMessaging", zip: true),
    Pod("FirebasePerformance", platforms: ["ios", "tvos"], zip: true),
    Pod("FirebaseStorage", zip: true),
    Pod("FirebaseStorageSwift", isBeta: true),
    Pod("FirebaseMLModelDownloader", isBeta: true, zip: true),
    Pod("Firebase", allowWarnings: true, zip: true),
  ]
)

/// Manifest describing the contents of a Firebase release.
public struct Manifest {
  public let version: String
  public let pods: [Pod]

  public func versionString(_ pod: Pod) -> String {
    return pod.isBeta ? version + "-beta" : version
  }
}
