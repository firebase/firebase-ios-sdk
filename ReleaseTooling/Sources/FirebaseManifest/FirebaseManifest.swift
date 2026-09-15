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
  version: "12.19.0",
  pods: [
    Pod("FirebaseSharedSwift"),
    Pod("FirebaseCoreInternal"),
    Pod("FirebaseCore"),
    Pod("FirebaseCoreExtension"),
    Pod("FirebaseInstallations"),
    Pod("FirebaseRemoteConfigInterop"),
    Pod("GoogleAppMeasurement", isClosedSource: true, platforms: ["ios", "macos", "tvos"]),
    Pod("FirebaseAnalytics", isClosedSource: true, platforms: ["ios", "macos", "tvos"], zip: true),
    Pod("FirebaseABTesting", zip: true),
    Pod("FirebaseRemoteConfig", zip: true),
    Pod("Firebase", allowWarnings: true, platforms: ["ios", "tvos", "macos"], zip: true),
  ]
)

/// Manifest describing the contents of a Firebase release.
public struct Manifest {
  public let version: String
  public let pods: [Pod]

  public func versionString(_ pod: Pod) -> String {
    let version = pod.podVersion ?? self.version
    return pod.isBeta ? version + "-beta" : version
  }
}
