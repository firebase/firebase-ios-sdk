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
  @_exported import FirebaseDatabaseInternal

  // This is a trick to force generate a `FirebaseDatabase-Swift.h`
  // header that re-exports `FirebaseDatabaseInternal` for Objective-C
  // clients. It is important for the below code to reference a Database
  // symbol defined in Objective-C as that will import the symbol's
  // module (`FirebaseDatabaseInternal`) in the generated header. This
  // allows Objective-C clients to import Database's Objective-C API
  // using `@import FirebaseDatabase;`. This API is not needed for Swift
  // clients and is therefore unavailable in a Swift context.
  @available(*, unavailable)
  @objc public extension Database {
    static var __no_op: () -> Void { {} }
  }
#endif // SWIFT_PACKAGE
