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

private import FirebaseCoreInternal

/// A `HTTPSCallableResult` contains the result of calling a `HTTPSCallable`.
@objc(FIRHTTPSCallableResult)
open class HTTPSCallableResult: NSObject {
  /// The data that was returned from the Callable HTTPS trigger.
  ///
  /// The data is in the form of native objects. For example, if your trigger returned an
  /// array, this object would be an `Array<Any>`. If your trigger returned a JavaScript object with
  /// keys and values, this object would be an instance of `[String: Any]`.
  @objc public let data: Any

  init(data: Any) {
    self.data = data
  }
}

/// A `HTTPSCallable` is a reference to a particular Callable HTTPS trigger in Cloud Functions.
@objc(FIRHTTPSCallable)
public final class HTTPSCallable: NSObject, Sendable {
  // MARK: - Private Properties

  // The functions client to use for making calls.
  private let functions: Functions

  private let url: URL

  private let options: HTTPSCallableOptions?

  private let _timeoutInterval: UnfairLock<TimeInterval> = .init(70)

  // MARK: - Public Properties

  /// The timeout to use when calling the function. Defaults to 70 seconds.
  @objc public var timeoutInterval: TimeInterval {
    get { _timeoutInterval.value() }
    set {
      _timeoutInterval.withLock { timeoutInterval in
        timeoutInterval = newValue
      }
    }
  }

  init(functions: Functions, url: URL, options: HTTPSCallableOptions? = nil) {
    self.functions = functions
    self.url = url
    self.options = options
  }

  /// Executes this Callable HTTPS trigger asynchronously.
  ///
  /// The data passed into the trigger can be any of the following types:
  /// - `nil` or `NSNull`
  /// - `String`
  /// - `NSNumber`, or any Swift numeric type bridgeable to `NSNumber`
  /// - `[Any]`, where the contained objects are also one of these types.
  /// - `[String: Any]` where the values are also one of these types.
  ///
  /// The request to the Cloud Functions backend made by this method automatically includes a
  /// Firebase Installations ID token to identify the app instance. If a user is logged in with
  /// Firebase Auth, an auth ID token for the user is also automatically included.
  ///
  /// Firebase Cloud Messaging sends data to the Firebase backend periodically to collect
  /// information
  /// regarding the app instance. To stop this, see `Messaging.deleteData()`. It
  /// resumes with a new FCM Token the next time you call this method.
  ///
  /// - Parameters:
  ///   - data: Parameters to pass to the trigger.
  ///   - completion: The block to call when the HTTPS request has completed.
  @available(swift 1000.0) // Objective-C only API
  @objc(callWithObject:completion:) public func call(_ data: Any? = nil,
                                                     completion: @escaping @MainActor (HTTPSCallableResult?,
                                                                                       Error?)
                                                       -> Void) {
    call(SendableWrapper(value: data as Any), completion: completion)
  }

  /// Executes this Callable HTTPS trigger asynchronously.
  ///
  /// The data passed into the trigger can be any of the following types:
  /// - `nil` or `NSNull`
  /// - `String`
  /// - `NSNumber`, or any Swift numeric type bridgeable to `NSNumber`
  /// - `[Any]`, where the contained objects are also one of these types.
  /// - `[String: Any]` where the values are also one of these types.
  ///
  /// The request to the Cloud Functions backend made by this method automatically includes a
  /// Firebase Installations ID token to identify the app instance. If a user is logged in with
  /// Firebase Auth, an auth ID token for the user is also automatically included.
  ///
  /// Firebase Cloud Messaging sends data to the Firebase backend periodically to collect
  /// information
  /// regarding the app instance. To stop this, see `Messaging.deleteData()`. It
  /// resumes with a new FCM Token the next time you call this method.
  ///
  /// - Parameters:
  ///   - data: Parameters to pass to the trigger.
  ///   - completion: The block to call when the HTTPS request has completed.
  @nonobjc public func call(_ data: sending Any? = nil,
                            completion: @escaping @MainActor (HTTPSCallableResult?,
                                                              Error?)
                              -> Void) {
    let data = (data as? SendableWrapper)?.value ?? data
    Task {
      do {
        let result = try await call(data)
        await completion(result, nil)
      } catch {
        await completion(nil, error)
      }
    }
  }

  /// Executes this Callable HTTPS trigger asynchronously. This API should only be used from
  /// Objective-C.
  ///
  /// The request to the Cloud Functions backend made by this method automatically includes a
  /// Firebase Installations ID token to identify the app instance. If a user is logged in with
  /// Firebase Auth, an auth ID token for the user is also automatically included.
  ///
  /// Firebase Cloud Messaging sends data to the Firebase backend periodically to collect
  /// information
  /// regarding the app instance. To stop this, see `Messaging.deleteData()`. It
  /// resumes with a new FCM Token the next time you call this method.
  ///
  /// - Parameter completion: The block to call when the HTTPS request has completed.
  @objc(callWithCompletion:) public func __call(completion: @escaping @MainActor (HTTPSCallableResult?,
                                                                                  Error?) -> Void) {
    call(nil, completion: completion)
  }

  /// Executes this Callable HTTPS trigger asynchronously.
  ///
  /// The request to the Cloud Functions backend made by this method automatically includes a
  /// FCM token to identify the app instance. If a user is logged in with Firebase
  /// Auth, an auth ID token for the user is also automatically included.
  ///
  /// Firebase Cloud Messaging sends data to the Firebase backend periodically to collect
  /// information
  /// regarding the app instance. To stop this, see `Messaging.deleteData()`. It
  /// resumes with a new FCM Token the next time you call this method.
  ///
  /// - Parameter data: Parameters to pass to the trigger.
  /// - Throws: An error if the Cloud Functions invocation failed.
  /// - Returns: The result of the call.
  public func call(_ data: Any? = nil) async throws -> sending HTTPSCallableResult {
    try await functions
      .callFunction(at: url, withObject: data, options: options, timeout: timeoutInterval)
  }

  @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
  func stream(_ data: SendableWrapper? = nil) -> AsyncThrowingStream<JSONStreamResponse, Error> {
    functions.stream(at: url, data: data, options: options, timeout: timeoutInterval)
  }
}
