// Copyright 2025 Google LLC
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

/// Versions of the Vertex AI in Firebase server API.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
// TODO(#14405): Make `APIVersion`, `v1` and `v1beta` public in Firebase 12.
struct APIVersion {
  /// The stable channel for version 1 of the API.
  static let v1 = APIVersion(versionIdentifier: "v1")

  /// The beta channel for version 1 of the API.
  static let v1beta = APIVersion(versionIdentifier: "v1beta")

  let versionIdentifier: String

  init(versionIdentifier: String) {
    self.versionIdentifier = versionIdentifier
  }
}
