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

#if SWIFT_PACKAGE
  @_exported import FirebaseRemoteConfigInternal

  // This is a trick to force generate a `FirebaseRemoteConfig-Swift.h` header
  // that re-exports `FirebaseRemoteConfigInternal` for Objective-C clients. It
  // is important for the below code to reference a Remote Config symbol defined
  // in Objective-C as that will import the symbol's module
  // (`FirebaseRemoteConfigInternal`) in the generated header. This allows
  // Objective-C clients to import Remote Config's Objective-C API using
  // `@import FirebaseRemoteConfig;`. This API is not needed for Swift clients
  // and is therefore unavailable in a Swift context.
  @available(*, unavailable)
  @objc public extension RemoteConfig {
    static var __no_op: () -> Void { {} }
  }
#endif // SWIFT_PACKAGE
