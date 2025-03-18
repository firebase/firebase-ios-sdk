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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
import FirebaseMessagingInterop
import FirebaseSharedSwift
import Foundation
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

// Avoids exposing internal FirebaseCore APIs to Swift users.
@_implementationOnly import FirebaseCoreExtension

final class AtomicBox<T> {
  private var _value: T
  private let lock = NSLock()

  public init(_ value: T) {
    _value = value
  }

  public func value() -> T {
    lock.withLock {
      _value
    }
  }

  @discardableResult
  public func withLock(_ mutatingBody: (_ value: inout T) -> Void) -> T {
    lock.withLock {
      mutatingBody(&_value)
      return _value
    }
  }

  @discardableResult
  public func withLock<R>(_ mutatingBody: (_ value: inout T) throws -> R) rethrows -> R {
    try lock.withLock {
      try mutatingBody(&_value)
    }
  }
}

/// File specific constants.
private enum Constants {
  static let appCheckTokenHeader = "X-Firebase-AppCheck"
  static let fcmTokenHeader = "Firebase-Instance-ID-Token"
}

/// Cross SDK constants.
enum FunctionsConstants {
  static let defaultRegion = "us-central1"
}

/// `Functions` is the client for Cloud Functions for a Firebase project.
@objc(FIRFunctions) open class Functions: NSObject {
  // MARK: - Private Variables

  /// The network client to use for http requests.
  private let fetcherService: GTMSessionFetcherService
  /// The projectID to use for all function references.
  private let projectID: String
  /// A serializer to encode/decode data and return values.
  private let serializer = FunctionsSerializer()
  /// A factory for getting the metadata to include with function calls.
  private let contextProvider: FunctionsContextProvider

  /// A map of active instances, grouped by app. Keys are FirebaseApp names and values are arrays
  /// containing all instances of Functions associated with the given app.
  #if compiler(>=6.0)
    private nonisolated(unsafe) static var instances: AtomicBox<[String: [Functions]]> =
      AtomicBox([:])
  #else
    private static var instances: AtomicBox<[String: [Functions]]> = AtomicBox([:])
  #endif

  /// The custom domain to use for all functions references (optional).
  let customDomain: String?

  /// The region to use for all function references.
  let region: String

  // MARK: - Public APIs

  /// The current emulator origin, or `nil` if it is not set.
  open private(set) var emulatorOrigin: String?

  /// Creates a Cloud Functions client using the default or returns a pre-existing instance if it
  /// already exists.
  /// - Returns: A shared Functions instance initialized with the default `FirebaseApp`.
  @objc(functions) open class func functions() -> Functions {
    return functions(
      app: FirebaseApp.app(),
      region: FunctionsConstants.defaultRegion,
      customDomain: nil
    )
  }

  /// Creates a Cloud Functions client with the given app, or returns a pre-existing
  /// instance if one already exists.
  /// - Parameter app: The app for the Firebase project.
  /// - Returns: A shared Functions instance initialized with the specified `FirebaseApp`.
  @objc(functionsForApp:) open class func functions(app: FirebaseApp) -> Functions {
    return functions(app: app, region: FunctionsConstants.defaultRegion, customDomain: nil)
  }

  /// Creates a Cloud Functions client with the default app and given region.
  ///  - Parameter region: The region for the HTTP trigger, such as `us-central1`.
  ///  - Returns: A shared Functions instance initialized with the default `FirebaseApp` and a
  /// custom region.
  @objc(functionsForRegion:) open class func functions(region: String) -> Functions {
    return functions(app: FirebaseApp.app(), region: region, customDomain: nil)
  }

  ///  Creates a Cloud Functions client with the given custom domain or returns a pre-existing
  ///  instance if one already exists.
  ///  - Parameter customDomain: A custom domain for the HTTP trigger, such as
  /// "https://mydomain.com".
  ///  - Returns: A shared Functions instance initialized with the default `FirebaseApp` and a
  /// custom HTTP trigger domain.
  @objc(functionsForCustomDomain:) open class func functions(customDomain: String) -> Functions {
    return functions(app: FirebaseApp.app(),
                     region: FunctionsConstants.defaultRegion, customDomain: customDomain)
  }

  ///  Creates a Cloud Functions client with the given app and region, or returns a pre-existing
  ///  instance if one already exists.
  ///  - Parameters:
  ///    - app: The app for the Firebase project.
  ///    - region: The region for the HTTP trigger, such as `us-central1`.
  ///  - Returns: An instance of `Functions` with a custom app and region.
  @objc(functionsForApp:region:) open class func functions(app: FirebaseApp,
                                                           region: String) -> Functions {
    return functions(app: app, region: region, customDomain: nil)
  }

  /// Creates a Cloud Functions client with the given app and custom domain, or returns a
  /// pre-existing
  /// instance if one already exists.
  ///  - Parameters:
  ///    - app: The app for the Firebase project.
  ///    - customDomain: A custom domain for the HTTP trigger, such as `https://mydomain.com`.
  ///  - Returns: An instance of `Functions` with a custom app and HTTP trigger domain.
  @objc(functionsForApp:customDomain:) open class func functions(app: FirebaseApp,
                                                                 customDomain: String)
    -> Functions {
    return functions(app: app, region: FunctionsConstants.defaultRegion, customDomain: customDomain)
  }

  /// Creates a reference to the Callable HTTPS trigger with the given name.
  /// - Parameter name: The name of the Callable HTTPS trigger.
  /// - Returns: A reference to a Callable HTTPS trigger.
  @objc(HTTPSCallableWithName:) open func httpsCallable(_ name: String) -> HTTPSCallable {
    HTTPSCallable(functions: self, url: functionURL(for: name)!)
  }

  /// Creates a reference to the Callable HTTPS trigger with the given name and configuration
  /// options.
  /// - Parameters:
  ///   - name: The name of the Callable HTTPS trigger.
  ///   - options: The options with which to customize the Callable HTTPS trigger.
  /// - Returns: A reference to a Callable HTTPS trigger.
  @objc(HTTPSCallableWithName:options:) public func httpsCallable(_ name: String,
                                                                  options: HTTPSCallableOptions)
    -> HTTPSCallable {
    HTTPSCallable(functions: self, url: functionURL(for: name)!, options: options)
  }

  /// Creates a reference to the Callable HTTPS trigger with the given name.
  /// - Parameter url: The URL of the Callable HTTPS trigger.
  /// - Returns: A reference to a Callable HTTPS trigger.
  @objc(HTTPSCallableWithURL:) open func httpsCallable(_ url: URL) -> HTTPSCallable {
    return HTTPSCallable(functions: self, url: url)
  }

  /// Creates a reference to the Callable HTTPS trigger with the given name and configuration
  /// options.
  /// - Parameters:
  ///   - url: The URL of the Callable HTTPS trigger.
  ///   - options: The options with which to customize the Callable HTTPS trigger.
  /// - Returns: A reference to a Callable HTTPS trigger.
  @objc(HTTPSCallableWithURL:options:) public func httpsCallable(_ url: URL,
                                                                 options: HTTPSCallableOptions)
    -> HTTPSCallable {
    return HTTPSCallable(functions: self, url: url, options: options)
  }

  /// Creates a reference to the Callable HTTPS trigger with the given name, the type of an
  /// `Encodable`
  /// request and the type of a `Decodable` response.
  /// - Parameters:
  ///   - name: The name of the Callable HTTPS trigger
  ///   - requestAs: The type of the `Encodable` entity to use for requests to this `Callable`
  ///   - responseAs: The type of the `Decodable` entity to use for responses from this `Callable`
  ///   - encoder: The encoder instance to use to perform encoding.
  ///   - decoder: The decoder instance to use to perform decoding.
  /// - Returns: A reference to an HTTPS-callable Cloud Function that can be used to make Cloud
  /// Functions invocations.
  open func httpsCallable<Request: Encodable,
    Response: Decodable>(_ name: String,
                         requestAs: Request.Type = Request.self,
                         responseAs: Response.Type = Response.self,
                         encoder: FirebaseDataEncoder = FirebaseDataEncoder(
                         ),
                         decoder: FirebaseDataDecoder = FirebaseDataDecoder(
                         ))
    -> Callable<Request, Response> {
    return Callable(
      callable: httpsCallable(name),
      encoder: encoder,
      decoder: decoder
    )
  }

  /// Creates a reference to the Callable HTTPS trigger with the given name, the type of an
  /// `Encodable`
  /// request and the type of a `Decodable` response.
  /// - Parameters:
  ///   - name: The name of the Callable HTTPS trigger
  ///   - options: The options with which to customize the Callable HTTPS trigger.
  ///   - requestAs: The type of the `Encodable` entity to use for requests to this `Callable`
  ///   - responseAs: The type of the `Decodable` entity to use for responses from this `Callable`
  ///   - encoder: The encoder instance to use to perform encoding.
  ///   - decoder: The decoder instance to use to perform decoding.
  /// - Returns: A reference to an HTTPS-callable Cloud Function that can be used to make Cloud
  /// Functions invocations.
  open func httpsCallable<Request: Encodable,
    Response: Decodable>(_ name: String,
                         options: HTTPSCallableOptions,
                         requestAs: Request.Type = Request.self,
                         responseAs: Response.Type = Response.self,
                         encoder: FirebaseDataEncoder = FirebaseDataEncoder(
                         ),
                         decoder: FirebaseDataDecoder = FirebaseDataDecoder(
                         ))
    -> Callable<Request, Response> {
    return Callable(
      callable: httpsCallable(name, options: options),
      encoder: encoder,
      decoder: decoder
    )
  }

  /// Creates a reference to the Callable HTTPS trigger with the given name, the type of an
  /// `Encodable`
  /// request and the type of a `Decodable` response.
  /// - Parameters:
  ///   - url: The url of the Callable HTTPS trigger
  ///   - requestAs: The type of the `Encodable` entity to use for requests to this `Callable`
  ///   - responseAs: The type of the `Decodable` entity to use for responses from this `Callable`
  ///   - encoder: The encoder instance to use to perform encoding.
  ///   - decoder: The decoder instance to use to perform decoding.
  /// - Returns: A reference to an HTTPS-callable Cloud Function that can be used to make Cloud
  /// Functions invocations.
  open func httpsCallable<Request: Encodable,
    Response: Decodable>(_ url: URL,
                         requestAs: Request.Type = Request.self,
                         responseAs: Response.Type = Response.self,
                         encoder: FirebaseDataEncoder = FirebaseDataEncoder(
                         ),
                         decoder: FirebaseDataDecoder = FirebaseDataDecoder(
                         ))
    -> Callable<Request, Response> {
    return Callable(
      callable: httpsCallable(url),
      encoder: encoder,
      decoder: decoder
    )
  }

  /// Creates a reference to the Callable HTTPS trigger with the given name, the type of an
  /// `Encodable`
  /// request and the type of a `Decodable` response.
  /// - Parameters:
  ///   - url: The url of the Callable HTTPS trigger
  ///   - options: The options with which to customize the Callable HTTPS trigger.
  ///   - requestAs: The type of the `Encodable` entity to use for requests to this `Callable`
  ///   - responseAs: The type of the `Decodable` entity to use for responses from this `Callable`
  ///   - encoder: The encoder instance to use to perform encoding.
  ///   - decoder: The decoder instance to use to perform decoding.
  /// - Returns: A reference to an HTTPS-callable Cloud Function that can be used to make Cloud
  /// Functions invocations.
  open func httpsCallable<Request: Encodable,
    Response: Decodable>(_ url: URL,
                         options: HTTPSCallableOptions,
                         requestAs: Request.Type = Request.self,
                         responseAs: Response.Type = Response.self,
                         encoder: FirebaseDataEncoder = FirebaseDataEncoder(
                         ),
                         decoder: FirebaseDataDecoder = FirebaseDataDecoder(
                         ))
    -> Callable<Request, Response> {
    return Callable(
      callable: httpsCallable(url, options: options),
      encoder: encoder,
      decoder: decoder
    )
  }

  /**
   * Changes this instance to point to a Cloud Functions emulator running locally.
   * See https://firebase.google.com/docs/functions/local-emulator
   * - Parameters:
   *   - host: The host of the local emulator, such as "localhost".
   *   - port: The port of the local emulator, for example 5005.
   */
  @objc open func useEmulator(withHost host: String, port: Int) {
    let prefix = host.hasPrefix("http") ? "" : "http://"
    let origin = String(format: "\(prefix)\(host):%li", port)
    emulatorOrigin = origin
  }

  // MARK: - Private Funcs (or Internal for tests)

  /// Solely used to have one precondition and one location where we fetch from the container. This
  /// previously was avoided due to default arguments but that doesn't work well with Obj-C
  /// compatibility.
  private class func functions(app: FirebaseApp?, region: String,
                               customDomain: String?) -> Functions {
    guard let app else {
      fatalError("`FirebaseApp.configure()` needs to be called before using Functions.")
    }

    return instances.withLock { instances in
      if let associatedInstances = instances[app.name] {
        for instance in associatedInstances {
          // Domains may be nil, so handle with care.
          var equalDomains = false
          if let instanceCustomDomain = instance.customDomain {
            equalDomains = instanceCustomDomain == customDomain
          } else {
            equalDomains = customDomain == nil
          }
          // Check if it's a match.
          if instance.region == region, equalDomains {
            return instance
          }
        }
      }
      let newInstance = Functions(app: app, region: region, customDomain: customDomain)
      let existingInstances = instances[app.name, default: []]
      instances[app.name] = existingInstances + [newInstance]
      return newInstance
    }
  }

  @objc init(projectID: String,
             region: String,
             customDomain: String?,
             auth: AuthInterop?,
             messaging: MessagingInterop?,
             appCheck: AppCheckInterop?,
             fetcherService: GTMSessionFetcherService = GTMSessionFetcherService()) {
    self.projectID = projectID
    self.region = region
    self.customDomain = customDomain
    emulatorOrigin = nil
    contextProvider = FunctionsContextProvider(auth: auth,
                                               messaging: messaging,
                                               appCheck: appCheck)
    self.fetcherService = fetcherService
  }

  /// Using the component system for initialization.
  convenience init(app: FirebaseApp,
                   region: String,
                   customDomain: String?) {
    // TODO: These are not optionals, but they should be.
    let auth = ComponentType<AuthInterop>.instance(for: AuthInterop.self, in: app.container)
    let messaging = ComponentType<MessagingInterop>.instance(for: MessagingInterop.self,
                                                             in: app.container)
    let appCheck = ComponentType<AppCheckInterop>.instance(for: AppCheckInterop.self,
                                                           in: app.container)

    guard let projectID = app.options.projectID else {
      fatalError("Firebase Functions requires the projectID to be set in the App's Options.")
    }
    self.init(projectID: projectID,
              region: region,
              customDomain: customDomain,
              auth: auth,
              messaging: messaging,
              appCheck: appCheck)
  }

  func functionURL(for name: String) -> URL? {
    assert(!name.isEmpty, "Name cannot be empty")

    // Check if we're using the emulator
    if let emulatorOrigin {
      return URL(string: "\(emulatorOrigin)/\(projectID)/\(region)/\(name)")
    }

    // Check the custom domain.
    if let customDomain {
      return URL(string: "\(customDomain)/\(name)")
    }

    return URL(string: "https://\(region)-\(projectID).cloudfunctions.net/\(name)")
  }

  @available(iOS 13, macCatalyst 13, macOS 10.15, tvOS 13, watchOS 7, *)
  func callFunction(at url: URL,
                    withObject data: Any?,
                    options: HTTPSCallableOptions?,
                    timeout: TimeInterval) async throws -> HTTPSCallableResult {
    let context = try await contextProvider.context(options: options)
    let fetcher = try makeFetcher(
      url: url,
      data: data,
      options: options,
      timeout: timeout,
      context: context
    )

    do {
      let rawData = try await fetcher.beginFetch()
      return try callableResult(fromResponseData: rawData, endpointURL: url)
    } catch {
      throw processedError(fromResponseError: error, endpointURL: url)
    }
  }

  func callFunction(at url: URL,
                    withObject data: Any?,
                    options: HTTPSCallableOptions?,
                    timeout: TimeInterval,
                    completion: @escaping ((Result<HTTPSCallableResult, Error>) -> Void)) {
    // Get context first.
    contextProvider.getContext(options: options) { context, error in
      // Note: context is always non-nil since some checks could succeed, we're only failing if
      // there's an error.
      if let error {
        completion(.failure(error))
      } else {
        self.callFunction(url: url,
                          withObject: data,
                          options: options,
                          timeout: timeout,
                          context: context,
                          completion: completion)
      }
    }
  }

  private func callFunction(url: URL,
                            withObject data: Any?,
                            options: HTTPSCallableOptions?,
                            timeout: TimeInterval,
                            context: FunctionsContext,
                            completion: @escaping ((Result<HTTPSCallableResult, Error>) -> Void)) {
    let fetcher: GTMSessionFetcher
    do {
      fetcher = try makeFetcher(
        url: url,
        data: data,
        options: options,
        timeout: timeout,
        context: context
      )
    } catch {
      DispatchQueue.main.async {
        completion(.failure(error))
      }
      return
    }

    fetcher.beginFetch { [self] data, error in
      let result: Result<HTTPSCallableResult, any Error>
      if let error {
        result = .failure(processedError(fromResponseError: error, endpointURL: url))
      } else if let data {
        do {
          result = try .success(callableResult(fromResponseData: data, endpointURL: url))
        } catch {
          result = .failure(error)
        }
      } else {
        result = .failure(FunctionsError(.internal))
      }

      DispatchQueue.main.async {
        completion(result)
      }
    }
  }

  @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
  func stream(at url: URL,
              data: Any?,
              options: HTTPSCallableOptions?,
              timeout: TimeInterval)
    -> AsyncThrowingStream<JSONStreamResponse, Error> {
    AsyncThrowingStream { continuation in
      Task {
        let urlRequest: URLRequest
        do {
          let context = try await contextProvider.context(options: options)
          urlRequest = try makeRequestForStreamableContent(
            url: url,
            data: data,
            options: options,
            timeout: timeout,
            context: context
          )
        } catch {
          continuation.finish(throwing: FunctionsError(
            .invalidArgument,
            userInfo: [NSUnderlyingErrorKey: error]
          ))
          return
        }

        let stream: URLSession.AsyncBytes
        let rawResponse: URLResponse
        do {
          (stream, rawResponse) = try await URLSession.shared.bytes(for: urlRequest)
        } catch {
          continuation.finish(throwing: FunctionsError(
            .unavailable,
            userInfo: [NSUnderlyingErrorKey: error]
          ))
          return
        }

        // Verify the status code is an HTTP response.
        guard let response = rawResponse as? HTTPURLResponse else {
          continuation.finish(
            throwing: FunctionsError(
              .unavailable,
              userInfo: [NSLocalizedDescriptionKey: "Response was not an HTTP response."]
            )
          )
          return
        }

        // Verify the status code is a 200.
        guard response.statusCode == 200 else {
          continuation.finish(
            throwing: FunctionsError(
              httpStatusCode: response.statusCode,
              region: region,
              url: url,
              body: nil,
              serializer: serializer
            )
          )
          return
        }

        do {
          for try await line in stream.lines {
            guard line.hasPrefix("data:") else {
              continuation.finish(
                throwing: FunctionsError(
                  .dataLoss,
                  userInfo: [NSLocalizedDescriptionKey: "Unexpected format for streamed response."]
                )
              )
              return
            }

            do {
              // We can assume 5 characters since it's utf-8 encoded, removing `data:`.
              let jsonText = String(line.dropFirst(5))
              let data = try jsonData(jsonText: jsonText)
              // Handle the content and parse it.
              let content = try callableStreamResult(fromResponseData: data, endpointURL: url)
              continuation.yield(content)
            } catch {
              continuation.finish(throwing: error)
              return
            }
          }
        } catch {
          continuation.finish(
            throwing: FunctionsError(
              .dataLoss,
              userInfo: [
                NSLocalizedDescriptionKey: "Unexpected format for streamed response.",
                NSUnderlyingErrorKey: error,
              ]
            )
          )
          return
        }

        continuation.finish()
      }
    }
  }

  #if compiler(>=6.0)
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    private func callableStreamResult(fromResponseData data: Data,
                                      endpointURL url: URL) throws -> sending JSONStreamResponse {
      let data = try processedData(fromResponseData: data, endpointURL: url)

      let responseJSONObject: Any
      do {
        responseJSONObject = try JSONSerialization.jsonObject(with: data)
      } catch {
        throw FunctionsError(.dataLoss, userInfo: [NSUnderlyingErrorKey: error])
      }

      guard let responseJSON = responseJSONObject as? [String: Any] else {
        let userInfo = [NSLocalizedDescriptionKey: "Response was not a dictionary."]
        throw FunctionsError(.dataLoss, userInfo: userInfo)
      }

      if let _ = responseJSON["result"] {
        return .result(responseJSON)
      } else if let _ = responseJSON["message"] {
        return .message(responseJSON)
      } else {
        throw FunctionsError(
          .dataLoss,
          userInfo: [NSLocalizedDescriptionKey: "Response is missing result or message field."]
        )
      }
    }
  #else
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    private func callableStreamResult(fromResponseData data: Data,
                                      endpointURL url: URL) throws -> JSONStreamResponse {
      let data = try processedData(fromResponseData: data, endpointURL: url)

      let responseJSONObject: Any
      do {
        responseJSONObject = try JSONSerialization.jsonObject(with: data)
      } catch {
        throw FunctionsError(.dataLoss, userInfo: [NSUnderlyingErrorKey: error])
      }

      guard let responseJSON = responseJSONObject as? [String: Any] else {
        let userInfo = [NSLocalizedDescriptionKey: "Response was not a dictionary."]
        throw FunctionsError(.dataLoss, userInfo: userInfo)
      }

      if let _ = responseJSON["result"] {
        return .result(responseJSON)
      } else if let _ = responseJSON["message"] {
        return .message(responseJSON)
      } else {
        throw FunctionsError(
          .dataLoss,
          userInfo: [NSLocalizedDescriptionKey: "Response is missing result or message field."]
        )
      }
    }
  #endif // compiler(>=6.0)

  private func jsonData(jsonText: String) throws -> Data {
    guard let data = jsonText.data(using: .utf8) else {
      throw FunctionsError(.dataLoss, userInfo: [
        NSUnderlyingErrorKey: DecodingError.dataCorrupted(DecodingError.Context(
          codingPath: [],
          debugDescription: "Could not parse response as UTF8."
        )),
      ])
    }
    return data
  }

  private func makeRequestForStreamableContent(url: URL,
                                               data: Any?,
                                               options: HTTPSCallableOptions?,
                                               timeout: TimeInterval,
                                               context: FunctionsContext) throws
    -> URLRequest {
    var urlRequest = URLRequest(
      url: url,
      cachePolicy: .useProtocolCachePolicy,
      timeoutInterval: timeout
    )

    let data = data ?? NSNull()
    let encoded = try serializer.encode(data)
    let body = ["data": encoded]
    let payload = try JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed])
    urlRequest.httpBody = payload

    // Set the headers for starting a streaming session.
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    urlRequest.httpMethod = "POST"

    if let authToken = context.authToken {
      let value = "Bearer \(authToken)"
      urlRequest.setValue(value, forHTTPHeaderField: "Authorization")
    }

    if let fcmToken = context.fcmToken {
      urlRequest.setValue(fcmToken, forHTTPHeaderField: Constants.fcmTokenHeader)
    }

    if options?.requireLimitedUseAppCheckTokens == true {
      if let appCheckToken = context.limitedUseAppCheckToken {
        urlRequest.setValue(
          appCheckToken,
          forHTTPHeaderField: Constants.appCheckTokenHeader
        )
      }
    } else if let appCheckToken = context.appCheckToken {
      urlRequest.setValue(
        appCheckToken,
        forHTTPHeaderField: Constants.appCheckTokenHeader
      )
    }

    return urlRequest
  }

  private func makeFetcher(url: URL,
                           data: Any?,
                           options: HTTPSCallableOptions?,
                           timeout: TimeInterval,
                           context: FunctionsContext) throws -> GTMSessionFetcher {
    let request = URLRequest(
      url: url,
      cachePolicy: .useProtocolCachePolicy,
      timeoutInterval: timeout
    )
    let fetcher = fetcherService.fetcher(with: request)

    let data = data ?? NSNull()
    let encoded = try serializer.encode(data)
    let body = ["data": encoded]
    let payload = try JSONSerialization.data(withJSONObject: body)
    fetcher.bodyData = payload

    // Set the headers.
    fetcher.setRequestValue("application/json", forHTTPHeaderField: "Content-Type")
    if let authToken = context.authToken {
      let value = "Bearer \(authToken)"
      fetcher.setRequestValue(value, forHTTPHeaderField: "Authorization")
    }

    if let fcmToken = context.fcmToken {
      fetcher.setRequestValue(fcmToken, forHTTPHeaderField: Constants.fcmTokenHeader)
    }

    if options?.requireLimitedUseAppCheckTokens == true {
      if let appCheckToken = context.limitedUseAppCheckToken {
        fetcher.setRequestValue(
          appCheckToken,
          forHTTPHeaderField: Constants.appCheckTokenHeader
        )
      }
    } else if let appCheckToken = context.appCheckToken {
      fetcher.setRequestValue(
        appCheckToken,
        forHTTPHeaderField: Constants.appCheckTokenHeader
      )
    }

    // Override normal security rules if this is a local test.
    if emulatorOrigin != nil {
      fetcher.allowLocalhostRequest = true
      fetcher.allowedInsecureSchemes = ["http"]
    }

    return fetcher
  }

  private func processedError(fromResponseError error: any Error,
                              endpointURL url: URL) -> any Error {
    let error = error as NSError
    let localError: (any Error)? = if error.domain == kGTMSessionFetcherStatusDomain {
      FunctionsError(
        httpStatusCode: error.code,
        region: region,
        url: url,
        body: error.userInfo["data"] as? Data,
        serializer: serializer
      )
    } else if error.domain == NSURLErrorDomain, error.code == NSURLErrorTimedOut {
      FunctionsError(.deadlineExceeded)
    } else { nil }

    return localError ?? error
  }

  private func callableResult(fromResponseData data: Data,
                              endpointURL url: URL) throws -> HTTPSCallableResult {
    let processedData = try processedData(fromResponseData: data, endpointURL: url)
    let json = try responseDataJSON(from: processedData)
    let payload = try serializer.decode(json)
    return HTTPSCallableResult(data: payload)
  }

  private func processedData(fromResponseData data: Data, endpointURL url: URL) throws -> Data {
    // `data` might specify a custom error. If so, throw the error.
    if let bodyError = FunctionsError(
      httpStatusCode: 200,
      region: region,
      url: url,
      body: data,
      serializer: serializer
    ) {
      throw bodyError
    }

    return data
  }

  private func responseDataJSON(from data: Data) throws -> Any {
    let responseJSONObject = try JSONSerialization.jsonObject(with: data)

    guard let responseJSON = responseJSONObject as? NSDictionary else {
      let userInfo = [NSLocalizedDescriptionKey: "Response was not a dictionary."]
      throw FunctionsError(.internal, userInfo: userInfo)
    }

    // `result` is checked for backwards compatibility:
    guard let dataJSON = responseJSON["data"] ?? responseJSON["result"] else {
      let userInfo = [NSLocalizedDescriptionKey: "Response is missing data field."]
      throw FunctionsError(.internal, userInfo: userInfo)
    }

    return dataJSON
  }
}
