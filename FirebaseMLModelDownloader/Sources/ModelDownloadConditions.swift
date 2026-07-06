// Copyright 2021 Google LLC
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

/// Model download conditions.
@available(
  *,
  deprecated,
  message: "Firebase ML is deprecated and will be shut down on June 15, 2027. To host custom models, you must migrate to another solution. You can use Cloud Storage for Firebase as an alternative for hosting custom models. For more info, see https://firebase.google.com/docs/ml/migrate-to-cloud-storage"
)
public struct ModelDownloadConditions {
  let allowsCellularAccess: Bool

  /// Conditions that need to be met to start a model file download.
  /// - Parameter allowsCellularAccess: Allow model downloading on a cellular connection. Default is
  /// `true`.
  public init(allowsCellularAccess: Bool = true) {
    self.allowsCellularAccess = allowsCellularAccess
  }
}
