// Copyright 2023 Google LLC
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

#warning(
  "All of the public API from `FirebaseRemoteConfigSwift` can now be accessed through the `FirebaseRemoteConfig` module. Therefore, the `FirebaseRemoteConfigSwift` module is deprecated and will be removed in the future. See https://firebase.google.com/docs/ios/swift-migration for migration instructions."
)

// The `@_exported` is needed to prevent breaking clients that are using
// types prefixed with the `FirebaseRemoteConfigSwift` module name (e.g.
// `FirebaseRemoteConfigSwift.RemoteConfigValueCodableError`).
@_exported import enum FirebaseRemoteConfig.RemoteConfigValueCodableError
@_exported import enum FirebaseRemoteConfig.RemoteConfigCodableError
@_exported import struct FirebaseRemoteConfig.RemoteConfigProperty
