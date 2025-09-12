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

@preconcurrency import FirebaseSharedSwift
import Foundation

/// A `Callable` is a reference to a particular Callable HTTPS trigger in Cloud Functions.
///
/// - Note: If the Callable HTTPS trigger accepts no parameters, ``Never`` can be used for
///   iOS 17.0+. Otherwise, a simple encodable placeholder type (e.g.,
///   `struct EmptyRequest: Encodable {}`) can be used.
public struct Callable<Request: Encodable, Response: Decodable>: Sendable {
  /// The timeout to use when calling the function. Defaults to 70 seconds.
  public var timeoutInterval: TimeInterval {
    get {
      callable.timeoutInterval
    }
    set {
      callable.timeoutInterval = newValue
    }
  }

  enum CallableError: Error {
    case internalError
  }

  private let callable: HTTPSCallable
  private let encoder: FirebaseDataEncoder
  private let decoder: FirebaseDataDecoder

  init(callable: HTTPSCallable, encoder: FirebaseDataEncoder, decoder: FirebaseDataDecoder) {
    self.callable = callable
    self.encoder = encoder
    self.decoder = decoder
  }

  /// Executes this Callable HTTPS trigger asynchronously.
  ///
  /// The data passed into the trigger must be of the generic `Request` type:
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
  /// - Parameter completion: The block to call when the HTTPS request has completed.
  public func call(_ data: Request,
                   completion: @escaping @MainActor (Result<Response, Error>)
                     -> Void) {
    do {
      let encoded = try SendableWrapper(value: encoder.encode(data))
      callable.call(encoded) { result, error in
        do {
          if let result {
            let decoded = try decoder.decode(Response.self, from: result.data)
            completion(.success(decoded))
          } else if let error {
            completion(.failure(error))
          } else {
            completion(.failure(CallableError.internalError))
          }
        } catch {
          completion(.failure(error))
        }
      }
    } catch {
      DispatchQueue.main.async {
        completion(.failure(error))
      }
    }
  }

  /// Creates a directly callable function.
  ///
  /// This allows users to call a HTTPS Callable Function like a normal Swift function:
  /// ```swift
  ///     let greeter = functions.httpsCallable("greeter",
  ///                                           requestType: GreetingRequest.self,
  ///                                           responseType: GreetingResponse.self)
  ///     greeter(data) { result in
  ///       print(result.greeting)
  ///     }
  /// ```
  /// You can also call a HTTPS Callable function using the following syntax:
  /// ```swift
  ///     let greeter: Callable<GreetingRequest, GreetingResponse> =
  /// functions.httpsCallable("greeter")
  ///     greeter(data) { result in
  ///       print(result.greeting)
  ///     }
  /// ```
  /// - Parameters:
  ///   - data: Parameters to pass to the trigger.
  ///   - completion: The block to call when the HTTPS request has completed.
  public func callAsFunction(_ data: Request,
                             completion: @escaping @MainActor (Result<Response, Error>)
                               -> Void) {
    call(data, completion: completion)
  }

  /// Executes this Callable HTTPS trigger asynchronously.
  ///
  /// The data passed into the trigger must be of the generic `Request` type:
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
  /// - Parameter data: The `Request` representing the data to pass to the trigger.
  ///
  /// - Throws: An error if any value throws an error during encoding or decoding.
  /// - Throws: An error if the callable fails to complete
  ///
  /// - Returns: The decoded `Response` value
  public func call(_ data: Request) async throws -> Response {
    let encoded = try encoder.encode(data)
    let result = try await callable.call(encoded)
    return try decoder.decode(Response.self, from: result.data)
  }

  /// Creates a directly callable function.
  ///
  /// This allows users to call a HTTPS Callable Function like a normal Swift function:
  /// ```swift
  ///     let greeter = functions.httpsCallable("greeter",
  ///                                           requestType: GreetingRequest.self,
  ///                                           responseType: GreetingResponse.self)
  ///     let result = try await greeter(data)
  ///     print(result.greeting)
  /// ```
  /// You can also call a HTTPS Callable function using the following syntax:
  /// ```swift
  ///     let greeter: Callable<GreetingRequest, GreetingResponse> =
  /// functions.httpsCallable("greeter")
  ///     let result = try await greeter(data)
  ///     print(result.greeting)
  /// ```
  /// - Parameters:
  ///   - data: Parameters to pass to the trigger.
  /// - Returns: The decoded `Response` value
  public func callAsFunction(_ data: Request) async throws -> Response {
    return try await call(data)
  }
}

/// Used to determine when a `StreamResponse<_, _>` is being decoded.
private protocol StreamResponseProtocol {}

/// A convenience type used to receive both the streaming callable function's yielded messages and
/// its return value.
///
/// This can be used as the generic `Response` parameter to ``Callable`` to receive both the
/// yielded messages and final return value of the streaming callable function.
@available(macOS 12.0, watchOS 8.0, *)
public enum StreamResponse<Message: Decodable & Sendable, Result: Decodable & Sendable>: Decodable,
  Sendable,
  StreamResponseProtocol {
  /// The message yielded by the callable function.
  case message(Message)
  /// The final result returned by the callable function.
  case result(Result)

  private enum CodingKeys: String, CodingKey {
    case message
    case result
  }

  public init(from decoder: any Decoder) throws {
    do {
      let container = try decoder
        .container(keyedBy: Self<Message, Result>.CodingKeys.self)
      guard let onlyKey = container.allKeys.first, container.allKeys.count == 1 else {
        throw DecodingError
          .typeMismatch(
            Self<Message,
              Result>.self,
            DecodingError.Context(
              codingPath: container.codingPath,
              debugDescription: "Invalid number of keys found, expected one.",
              underlyingError: nil
            )
          )
      }

      switch onlyKey {
      case .message:
        self = try Self
          .message(container.decode(Message.self, forKey: .message))
      case .result:
        self = try Self
          .result(container.decode(Result.self, forKey: .result))
      }
    } catch {
      throw FunctionsError(.dataLoss, userInfo: [NSUnderlyingErrorKey: error])
    }
  }
}

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public extension Callable where Request: Sendable, Response: Sendable {
  /// Creates a stream that yields responses from the streaming callable function.
  ///
  /// The request to the Cloud Functions backend made by this method automatically includes a FCM
  /// token to identify the app instance. If a user is logged in with Firebase Auth, an auth ID
  /// token for the user is included. If App Check is integrated, an app check token is included.
  ///
  /// Firebase Cloud Messaging sends data to the Firebase backend periodically to collect
  /// information regarding the app instance. To stop this, see `Messaging.deleteData()`. It
  /// resumes with a new FCM Token the next time you call this method.
  ///
  /// - Important: The final result returned by the callable function is only accessible when
  ///   using `StreamResponse` as the `Response` generic type.
  ///
  /// Example of using `stream` _without_ `StreamResponse`:
  /// ```swift
  /// let callable: Callable<MyRequest, MyResponse> = // ...
  /// let request: MyRequest = // ...
  /// let stream = try callable.stream(request)
  /// for try await response in stream {
  ///   // Process each `MyResponse` message
  ///   print(response)
  /// }
  /// ```
  ///
  /// Example of using `stream` _with_ `StreamResponse`:
  /// ```swift
  /// let callable: Callable<MyRequest, StreamResponse<MyMessage, MyResult>> = // ...
  /// let request: MyRequest = // ...
  /// let stream = try callable.stream(request)
  /// for try await response in stream {
  ///   switch response {
  ///   case .message(let message):
  ///     // Process each `MyMessage`
  ///     print(message)
  ///   case .result(let result):
  ///     // Process the final `MyResult`
  ///     print(result)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter data: The `Request` data to pass to the callable function.
  /// - Throws: A ``FunctionsError`` if the parameter `data` cannot be encoded.
  /// - Returns: A stream wrapping responses yielded by the streaming callable function or
  ///   a ``FunctionsError`` if an error occurred.
  func stream(_ data: Request? = nil) throws -> AsyncThrowingStream<Response, Error> {
    let encoded: SendableWrapper
    do {
      encoded = try SendableWrapper(value: encoder.encode(data))
    } catch {
      throw FunctionsError(.invalidArgument, userInfo: [NSUnderlyingErrorKey: error])
    }

    return AsyncThrowingStream { continuation in
      Task {
        do {
          for try await response in callable.stream(encoded) {
            do {
              // This response JSON should only be able to be decoded to an `StreamResponse<_, _>`
              // instance. If the decoding succeeds and the decoded response conforms to
              // `StreamResponseProtocol`, we know the `Response` generic argument
              // is `StreamResponse<_, _>`.
              let responseJSON = switch response {
              case let .message(json), let .result(json): json
              }
              let response = try decoder.decode(Response.self, from: responseJSON)
              if response is StreamResponseProtocol {
                continuation.yield(response)
              } else {
                // `Response` is a custom type that matched the decoding logic as the
                // `StreamResponse<_, _>` type. Only the `StreamResponse<_, _>` type should decode
                // successfully here to avoid exposing the `result` value in a custom type.
                throw FunctionsError(.internal)
              }
            } catch let error as FunctionsError where error.code == .dataLoss {
              // `Response` is of type `StreamResponse<_, _>`, but failed to decode. Rethrow.
              throw error
            } catch {
              // `Response` is *not* of type `StreamResponse<_, _>`, and needs to be unboxed and
              // decoded.
              guard case let .message(messageJSON) = response else {
                // Since `Response` is not a `StreamResponse<_, _>`, only messages should be
                // decoded.
                continue
              }

              do {
                let boxedMessage = try decoder.decode(
                  StreamResponseMessage.self,
                  from: messageJSON
                )
                continuation.yield(boxedMessage.message)
              } catch {
                throw FunctionsError(.dataLoss, userInfo: [NSUnderlyingErrorKey: error])
              }
            }
          }
        } catch {
          continuation.finish(throwing: error)
        }
        continuation.finish()
      }
    }
  }

  /// A container type for the type-safe decoding of the message object from the generic `Response`
  /// type.
  private struct StreamResponseMessage: Decodable {
    let message: Response
  }
}

/// A container type for differentiating between message and result responses.
enum JSONStreamResponse {
  case message([String: Any])
  case result([String: Any])
}

// TODO(Swift 6): Remove need for below type by changing `FirebaseDataEncoder` to not returning
// `Any`.
/// This wrapper is only intended to be used for passing encoded data in the
/// `stream` function's hierarchy. When using, carefully audit that `value` is
/// only ever accessed in one isolation domain.
struct SendableWrapper: @unchecked Sendable {
  let value: Any
}
