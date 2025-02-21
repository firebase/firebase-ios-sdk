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

import FirebaseSharedSwift
import Foundation

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
enum StreamResponseError: Error {
  case decodingFailure(underlyingError: any Error)
}

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public enum StreamResponse<Message: Decodable, Result: Decodable>: Decodable {
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
        .container(keyedBy: StreamResponse<Message, Result>.CodingKeys.self)
      var allKeys = ArraySlice(container.allKeys)
      guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
        throw DecodingError
          .typeMismatch(
            StreamResponse<Message,
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
        self = try StreamResponse
          .message(container.decode(Message.self, forKey: .message))
      case .result:
        self = try StreamResponse
          .result(container.decode(Result.self, forKey: .result))
      }
    } catch {
      throw StreamResponseError.decodingFailure(underlyingError: error)
    }
  }
}

/// A `Callable` is reference to a particular Callable HTTPS trigger in Cloud Functions.
public struct Callable<Request: Encodable, Response: Decodable> {
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
                   completion: @escaping (Result<Response, Error>)
                     -> Void) {
    do {
      let encoded = try encoder.encode(data)

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
      completion(.failure(error))
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
                             completion: @escaping (Result<Response, Error>)
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
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
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
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func callAsFunction(_ data: Request) async throws -> Response {
    return try await call(data)
  }
}

public extension Callable {
  // TODO: Look into handling parameter-less functions.
  // TODO: Ensure decoding failures are passed into reasonable errors.
  @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
  func stream(_ data: Request) -> AsyncThrowingStream<Response, Error> {
    return AsyncThrowingStream { continuation in
      Task {
        do {
          let encoded = try encoder.encode(data)
          for try await result in callable.stream(encoded) {
            do {
              // Due to the way the response data is boxed by the SDK, this will succeed in the
              // following cases.
              // (a) Response is of type `StreamResponse<_, _>`
              // (b) Response is a custom type that matches structure of type `StreamResponse<_, _>`
              // TODO: Probably can address (b) by making firebase-specific custom key. Is it worth it though?
              let response = try decoder.decode(Response.self, from: result.data)
              continuation.yield(response)
            } catch let StreamResponseError.decodingFailure(underlyingError: error) {
              // `Response` is of type `StreamResponse<_, _>`, but failed to decode. Rethrow.
              // TODO: Wrap in Functions error.
              throw error
            } catch {
              // `Response` is *not* of type `StreamResponse<_, _>`, and needs to be unboxed and
              // decoded.
              // TODO: We need to be careful to not decode the result here. We can't catch an error here
              // because of the case where the result type is same as message type. We need to have
              // the information
              // here to know if we are trying to decode a result vs. a message.
              let response = try decoder.decode([String: Response].self, from: result.data)
              // TODO: Above error may need to be cleaned up (caught) due to custom boxing.
              guard let message = response["message"] else {
                // Since `Response` is not a `StreamResponse<_, _>`, only messages should be
                // decoded.
                continue
              }
              continuation.yield(message)
            }
          }
        } catch {
          continuation.finish(throwing: error)
        }
        continuation.finish()
      }
    }
  }
}
