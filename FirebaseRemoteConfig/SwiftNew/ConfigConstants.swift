// Copyright 2024 Google LLC
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

enum ConfigConstants {
  static let _SEC_PER_MIN = 60
  static let _MSEC_PER_SEC = 1000

  static let internalMetadataAllPackagesPrefix = "all_packages"

  static let httpDefaultConnectionTimeout: TimeInterval = 60
  static let defaultMinimumFetchInterval: TimeInterval = 43200

  static let remoteConfigQueueLabel = "com.google.GoogleConfigService.FIRRemoteConfig"

  // MARK: - Fetch Response Keys

  static let fetchResponseKeyEntries = "entries"
  static let fetchResponseKeyExperimentDescriptions = "experimentDescriptions"
  static let fetchResponseKeyPersonalizationMetadata = "personalizationMetadata"
  static let fetchResponseKeyRolloutMetadata = "rolloutMetadata"
  static let fetchResponseKeyRolloutID = "rolloutId"
  static let fetchResponseKeyVariantID = "variantId"
  static let fetchResponseKeyAffectedParameterKeys = "affectedParameterKeys"
  static let fetchResponseKeyError = "error"
  static let fetchResponseKeyErrorCode = "code"
  static let fetchResponseKeyErrorStatus = "status"
  static let fetchResponseKeyErrorMessage = "message"
  static let fetchResponseKeyState = "state"
  static let fetchResponseKeyStateUnspecified = "INSTANCE_STATE_UNSPECIFIED"
  static let fetchResponseKeyStateUpdate = "UPDATE"
  static let fetchResponseKeyStateNoTemplate = "NO_TEMPLATE"
  static let fetchResponseKeyStateNoChange = "NO_CHANGE"
  static let fetchResponseKeyStateEmptyConfig = "EMPTY_CONFIG"
  static let fetchResponseKeyTemplateVersion = "templateVersion"
  static let activeKeyTemplateVersion = "activeTemplateVersion"

  // MARK: Formerly RCNConfigDefines.h

  static let experimentTableKeyPayload = "experiment_payload"
  static let experimentTableKeyMetadata = "experiment_metadata"
  static let experimentTableKeyActivePayload = "experiment_active_payload"
  static let rolloutTableKeyActiveMetadata = "active_rollout_metadata"
  static let rolloutTableKeyFetchedMetadata = "fetched_rollout_metadata"
}
