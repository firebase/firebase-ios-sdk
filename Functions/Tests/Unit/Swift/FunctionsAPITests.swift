//
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
//

// MARK: This file is used to evaluate the experience of using Firebase APIs in Swift.

import Foundation

import FirebaseCore
import FirebaseFunctions

final class FunctionsAPITests {
  func usage() {
    // MARK: - Functions

    // Retrieve Functions instance
    _ = Functions.functions()

    if let app = FirebaseApp.app() {
      _ = Functions.functions(app: app)
      _ = Functions.functions(app: app, region: "alderaan")
      _ = Functions.functions(app: app, customDomain: "https://visitalderaan.com")
    }

    _ = Functions.functions(region: "alderaan")
    _ = Functions.functions(customDomain: "https://visitalderaan.com")

    // Reference to a callable HTTPS trigger
    _ = Functions.functions().httpsCallable("setCourseForAlderaan")

    // Functions emulator
    Functions.functions().useEmulator(withHost: "host", port: 3000)
    if let _ /* emulatorOrigin */ = Functions.functions().emulatorOrigin {
      // ...
    }

    // MARK: - HTTPSCallable

    let callableRef = Functions.functions().httpsCallable("setCourseForAlderaan")
    callableRef.timeoutInterval = 60

    let data: Any? = nil
    callableRef.call(data) { result, error in
      if let result = result {
        _ = result.data
      } else if let _ /* error */ = error {
        // ...
      }
    }

    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            let result = try await callableRef.call(data)
            _ = result.data
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    callableRef.call { result, error in
      if let result = result {
        _ = result.data
      } else if let _ /* error */ = error {
        // ...
      }
    }

    #if swift(>=5.5)
      if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *) {
        // async/await is a Swift 5.5+ feature available on iOS 15+
        async {
          do {
            let result = try await callableRef.call()
            _ = result.data
          } catch {
            // ...
          }
        }
      }
    #endif // swift(>=5.5)

    // MARK: - FunctionsErrorCode

    callableRef.call { _, error in
      if let error = error {
        switch (error as NSError).code {
        case FunctionsErrorCode.OK.rawValue:
          break
        case FunctionsErrorCode.cancelled.rawValue:
          break
        case FunctionsErrorCode.unknown.rawValue:
          break
        case FunctionsErrorCode.invalidArgument.rawValue:
          break
        case FunctionsErrorCode.deadlineExceeded.rawValue:
          break
        case FunctionsErrorCode.notFound.rawValue:
          break
        case FunctionsErrorCode.alreadyExists.rawValue:
          break
        case FunctionsErrorCode.permissionDenied.rawValue:
          break
        case FunctionsErrorCode.resourceExhausted.rawValue:
          break
        case FunctionsErrorCode.failedPrecondition.rawValue:
          break
        case FunctionsErrorCode.aborted.rawValue:
          break
        case FunctionsErrorCode.outOfRange.rawValue:
          break
        case FunctionsErrorCode.unimplemented.rawValue:
          break
        case FunctionsErrorCode.internal.rawValue:
          break
        case FunctionsErrorCode.unavailable.rawValue:
          break
        case FunctionsErrorCode.dataLoss.rawValue:
          break
        case FunctionsErrorCode.unauthenticated.rawValue:
          break
        default:
          break
        }
      }
    }
  }
}
