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

// Swift Package Manager builds the networking code as its own module, `FirebaseNetworkingInternal`,
// so that it also builds on Linux. Re-exporting it lets SDKs write
// `@_spi(FirebaseNetworking) import FirebaseCoreInternal` with every build system. CocoaPods
// compiles the networking sources into this module, so the module doesn't exist there and this
// line isn't needed.
#if canImport(FirebaseNetworkingInternal)
  @_spi(FirebaseNetworking) @_exported public import FirebaseNetworkingInternal
#endif
