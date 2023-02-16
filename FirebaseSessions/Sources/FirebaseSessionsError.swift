// Copyright 2022 Google LLC
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

/// Contains the list of errors that are localized for Firebase Sessions Library
enum FirebaseSessionsError: Error {
  /// Event sampling related error
  case SessionSamplingError
  /// Firebase Installation ID related error
  case SessionInstallationsError(Error)
  /// Error from the GoogleDataTransport SDK
  case DataTransportError(Error)
  /// Sessions SDK is disabled via settings error
  case DisabledViaSettingsError
  /// Sessions SDK is disabled because all Subscribers have their
  /// data collection disabled
  case DataCollectionError
  /// Sessions SDK didn't have any Subscribers depend
  /// on it via addDependency in SessionDependencies
  case NoDependenciesError
}
