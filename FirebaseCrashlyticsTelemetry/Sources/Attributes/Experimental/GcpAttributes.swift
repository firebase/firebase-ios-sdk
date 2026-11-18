// Copyright 2026 Google LLC
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

import OpenTelemetryApi

extension SemanticConventions.Gcp {
  /// The Google Cloud project ID in which to store telemetry data.
  static let crashlyticsProjectId = "gcp.project_id"

  /// The Firebase App ID (`googleAppID`) identifying the client application.
  static let crashlyticsFirebaseAppId = "gcp.firebase.app_id"

  /// The specific client library artifact producing the telemetry.
  static let crashlyticsClientArtifact = "gcp.client.artifact"

  /// The source repository (without `"github.com/"`) containing the client library code.
  static let crashlyticsClientRepo = "gcp.client.repo"

  /// The version of the client library invoking the service.
  static let crashlyticsClientVersion = "gcp.client.version"
}
