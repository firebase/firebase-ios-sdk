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

#if canImport(Combine) && swift(>=5.0)

  import Combine
  import FirebaseFunctions

  @available(swift 5.0)
  @available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, *)
  extension HTTPSCallable {
    // MARK: - HTTPS Callable Functions

    /// Executes this Callable HTTPS trigger asynchronously without any parameters.
    ///
    /// The publisher will emit on the **main** thread.
    ///
    /// The request to the Cloud Functions backend made by this method automatically includes a
    /// Firebase Instance ID token to identify the app instance. If a user is logged in with Firebase
    /// Auth, an auth ID token for the user is also automatically included.
    ///
    /// Firebase Installations ID sends data to the Firebase backend periodically to collect information
    /// regarding the app instance. To stop this, see `[FIRInstallations delete]`. It
    /// resumes with a new Instance ID the next time you call this method.
    ///
    /// - Returns: A publisher emitting a `HTTPSCallableResult` instance. The publisher will emit on the *main* thread.
    @discardableResult
    public func call() -> Future<HTTPSCallableResult, Error> {
      Future<HTTPSCallableResult, Error> { promise in
        self.call { callableResult, error in
          if let error = error {
            promise(.failure(error))
          } else if let callableResult = callableResult {
            promise(.success(callableResult))
          }
        }
      }
    }

    /// Executes this Callable HTTPS trigger asynchronously.
    ///
    /// The publisher will emit on the **main** thread.
    ///
    /// The data passed into the trigger can be any of the following types:
    /// - `nil`
    /// - `String`
    /// - `Number`
    /// - `Array<Any>`, where the contained objects are also one of these types.
    /// - `Dictionary<String, Any>`, where the contained objects are also one of these types.
    ///
    /// The request to the Cloud Functions backend made by this method automatically includes a
    /// Firebase Instance ID token to identify the app instance. If a user is logged in with Firebase
    /// Auth, an auth ID token for the user is also automatically included.
    ///
    /// Firebase Instance ID sends data to the Firebase backend periodically to collect information
    /// regarding the app instance. To stop this, see `[FIRInstanceID deleteIDWithHandler:]`. It
    /// resumes with a new Instance ID the next time you call this method.
    ///
    /// - Parameter data: The data passed into the Callable Function.
    /// - Returns: A publisher emitting a `HTTPSCallableResult` instance. The publisher will emit on the *main* thread.
    @discardableResult
    public func call(_ data: Any?) -> Future<HTTPSCallableResult, Error> {
      Future<HTTPSCallableResult, Error> { promise in
        self.call(data) { callableResult, error in
          if let error = error {
            promise(.failure(error))
          } else if let callableResult = callableResult {
            promise(.success(callableResult))
          }
        }
      }
    }
  }

#endif // canImport(Combine) && swift(>=5.0) && canImport(FirebaseFunctions)
