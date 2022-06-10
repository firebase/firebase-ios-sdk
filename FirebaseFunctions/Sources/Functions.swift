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
import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
import FirebaseMessagingInterop
import FirebaseSharedSwift
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

// Avoids exposing internal FirebaseCore APIs to Swift users.
@_implementationOnly import FirebaseCoreExtension

/// File specific constants.
private enum Constants {
  static let appCheckTokenHeader = "X-Firebase-AppCheck"
  static let fcmTokenHeader = "Firebase-Instance-ID-Token"
}

/// Cross SDK constants.
internal enum FunctionsConstants {
  static let defaultRegion = "us-central1"
}

/**
 * `Functions` is the client for Cloud Functions for a Firebase project.
 */
@objc(FIRFunctions) open class Functions: NSObject {
  // MARK: - Private Variables

  /// The network client to use for http requests.
  private let fetcherService: GTMSessionFetcherService
  /// The projectID to use for all function references.
  private let projectID: String
  /// A serializer to encode/decode data and return values.
  private let serializer = FUNSerializer()
  /// A factory for getting the metadata to include with function calls.
  private let contextProvider: FunctionsContextProvider

  /// The custom domain to use for all functions references (optional).
  internal let customDomain: String?

  /// The region to use for all function references.
  internal let region: String

  // MARK: - Public APIs

  /**
   * The current emulator origin, or `nil` if it is not set.
   */
  open private(set) var emulatorOrigin: String?

  /**
   * Creates a Cloud Functions client using the default or returns a pre-existing instance if it already exists.
   * - Returns: A shared Functions instance initialized with the default `FirebaseApp`.
   */
  @objc(functions) open class func functions() -> Functions {
    return functions(
      app: FirebaseApp.app(),
      region: FunctionsConstants.defaultRegion,
      customDomain: nil
    )
  }

  /**
   * Creates a Cloud Functions client with the given app, or returns a pre-existing
   * instance if one already exists.
   * - Parameter app The app for the Firebase project.
   * - Returns: A shared Functions instance initialized with the specified `FirebaseApp`.
   */
  @objc(functionsForApp:) open class func functions(app: FirebaseApp) -> Functions {
    return functions(app: app, region: FunctionsConstants.defaultRegion, customDomain: nil)
  }

  /**
   * Creates a Cloud Functions client with the default app and given region.
   * - Parameter region The region for the HTTP trigger, such as `us-central1`.
   * - Returns: A shared Functions instance initialized with the default `FirebaseApp` and a custom region.
   */
  @objc(functionsForRegion:) open class func functions(region: String) -> Functions {
    return functions(app: FirebaseApp.app(), region: region, customDomain: nil)
  }

  /**
   * Creates a Cloud Functions client with the given app and region, or returns a pre-existing
   * instance if one already exists.
   * - Parameter customDomain A custom domain for the HTTP trigger, such as "https://mydomain.com".
   * - Returns: A shared Functions instance initialized with the default `FirebaseApp` and a custom HTTP trigger domain.
   */
  @objc(functionsForCustomDomain:) open class func functions(customDomain: String) -> Functions {
    return functions(app: FirebaseApp.app(),
                     region: FunctionsConstants.defaultRegion, customDomain: customDomain)
  }

  /**
   * Creates a Cloud Functions client with the given app and region, or returns a pre-existing
   * instance if one already exists.
   * - Parameters:
   *   - app: The app for the Firebase project.
   *   - region: The region for the HTTP trigger, such as `us-central1`.
   * - Returns: An instance of `Functions` with a custom app and region.
   */
  @objc(functionsForApp:region:) open class func functions(app: FirebaseApp,
                                                           region: String) -> Functions {
    return functions(app: app, region: region, customDomain: nil)
  }

  /**
   * Creates a Cloud Functions client with the given app and region, or returns a pre-existing
   * instance if one already exists.
   * - Parameters:
   *   - app The app for the Firebase project.
   *   - customDomain A custom domain for the HTTP trigger, such as `https://mydomain.com`.
   * - Returns: An instance of `Functions` with a custom app and HTTP trigger domain.
   */
  @objc(functionsForApp:customDomain:) open class func functions(app: FirebaseApp,
                                                                 customDomain: String)
    -> Functions {
    return functions(app: app, region: FunctionsConstants.defaultRegion, customDomain: customDomain)
  }

  /**
   * Creates a reference to the Callable HTTPS trigger with the given name.
   * - Parameter name The name of the Callable HTTPS trigger.
   */
  @objc(HTTPSCallableWithName:) open func httpsCallable(_ name: String) -> HTTPSCallable {
    return HTTPSCallable(functions: self, name: name)
  }

  @objc(HTTPSCallableWithURL:) open func httpsCallable(_ url: URL) -> HTTPSCallable {
    return HTTPSCallable(functions: self, url: url)
  }

  /// Creates a reference to the Callable HTTPS trigger with the given name, the type of an `Encodable`
  /// request and the type of a `Decodable` response.
  /// - Parameter name: The name of the Callable HTTPS trigger
  /// - Parameter requestAs: The type of the `Encodable` entity to use for requests to this `Callable`
  /// - Parameter responseAs: The type of the `Decodable` entity to use for responses from this `Callable`
  /// - Parameter encoder: The encoder instance to use to run the encoding.
  /// - Parameter decoder: The decoder instance to use to run the decoding.
  /// - Returns: A reference to an HTTPS-callable Cloud Function that can be used to make Cloud Functions invocations.
  open func httpsCallable<Request: Encodable,
    Response: Decodable>(_ name: String,
                         requestAs: Request.Type = Request.self,
                         responseAs: Response.Type = Response.self,
                         encoder: FirebaseDataEncoder = FirebaseDataEncoder(
                         ),
                         decoder: FirebaseDataDecoder = FirebaseDataDecoder(
                         ))
    -> Callable<Request, Response> {
    return Callable(callable: httpsCallable(name), encoder: encoder, decoder: decoder)
  }

  /// Creates a reference to the Callable HTTPS trigger with the given name, the type of an `Encodable`
  /// request and the type of a `Decodable` response.
  /// - Parameter url: The url of the Callable HTTPS trigger
  /// - Parameter requestAs: The type of the `Encodable` entity to use for requests to this `Callable`
  /// - Parameter responseAs: The type of the `Decodable` entity to use for responses from this `Callable`
  /// - Parameter encoder: The encoder instance to use to run the encoding.
  /// - Parameter decoder: The decoder instance to use to run the decoding.
  /// - Returns: A reference to an HTTPS-callable Cloud Function that can be used to make Cloud Functions invocations.
  open func httpsCallable<Request: Encodable,
    Response: Decodable>(_ url: URL,
                         requestAs: Request.Type = Request.self,
                         responseAs: Response.Type = Response.self,
                         encoder: FirebaseDataEncoder = FirebaseDataEncoder(
                         ),
                         decoder: FirebaseDataDecoder = FirebaseDataDecoder(
                         ))
    -> Callable<Request, Response> {
    return Callable(callable: httpsCallable(url), encoder: encoder, decoder: decoder)
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
  /// previously was avoided due to default arguments but that doesn't work well with Obj-C compatibility.
  private class func functions(app: FirebaseApp?, region: String,
                               customDomain: String?) -> Functions {
    precondition(app != nil,
                 "`FirebaseApp.configure()` needs to be called before using Functions.")
    let provider = app!.container.instance(for: FunctionsProvider.self) as? FunctionsProvider
    return provider!.functions(for: app!,
                               region: region,
                               customDomain: customDomain,
                               type: self)
  }

  @objc internal init(projectID: String,
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
  internal convenience init(app: FirebaseApp,
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

  internal func urlWithName(_ name: String) -> String {
    assert(!name.isEmpty, "Name cannot be empty")

    // Check if we're using the emulator
    if let emulatorOrigin = emulatorOrigin {
      return "\(emulatorOrigin)/\(projectID)/\(region)/\(name)"
    }

    // Check the custom domain.
    if let customDomain = customDomain {
      return "\(customDomain)/\(name)"
    }

    return "https://\(region)-\(projectID).cloudfunctions.net/\(name)"
  }

  internal func callFunction(name: String,
                             withObject data: Any?,
                             timeout: TimeInterval,
                             completion: @escaping ((Result<HTTPSCallableResult, Error>) -> Void)) {
    // Get context first.
    contextProvider.getContext { context, error in
      // Note: context is always non-nil since some checks could succeed, we're only failing if
      // there's an error.
      if let error = error {
        completion(.failure(error))
      } else {
        let url = self.urlWithName(name)
        self.callFunction(url: URL(string: url)!,
                          withObject: data,
                          timeout: timeout,
                          context: context,
                          completion: completion)
      }
    }
  }

  internal func callFunction(url: URL,
                             withObject data: Any?,
                             timeout: TimeInterval,
                             completion: @escaping ((Result<HTTPSCallableResult, Error>) -> Void)) {
    // Get context first.
    contextProvider.getContext { context, error in
      // Note: context is always non-nil since some checks could succeed, we're only failing if
      // there's an error.
      if let error = error {
        completion(.failure(error))
      } else {
        self.callFunction(url: url,
                          withObject: data,
                          timeout: timeout,
                          context: context,
                          completion: completion)
      }
    }
  }

  private func callFunction(url: URL,
                            withObject data: Any?,
                            timeout: TimeInterval,
                            context: FunctionsContext,
                            completion: @escaping ((Result<HTTPSCallableResult, Error>) -> Void)) {
    let request = URLRequest(url: url,
                             cachePolicy: .useProtocolCachePolicy,
                             timeoutInterval: timeout)
    let fetcher = fetcherService.fetcher(with: request)
    let body = NSMutableDictionary()

    // Encode the data in the body.
    var localData = data
    if data == nil {
      localData = NSNull()
    }
    // Force unwrap to match the old invalid argument thrown.
    let encoded = try! serializer.encode(localData!)
    body["data"] = encoded

    do {
      let payload = try JSONSerialization.data(withJSONObject: body)
      fetcher.bodyData = payload
    } catch {
      DispatchQueue.main.async {
        completion(.failure(error))
      }
      return
    }

    // Set the headers.
    fetcher.setRequestValue("application/json", forHTTPHeaderField: "Content-Type")
    if let authToken = context.authToken {
      let value = "Bearer \(authToken)"
      fetcher.setRequestValue(value, forHTTPHeaderField: "Authorization")
    }

    if let fcmToken = context.fcmToken {
      fetcher.setRequestValue(fcmToken, forHTTPHeaderField: Constants.fcmTokenHeader)
    }

    if let appCheckToken = context.appCheckToken {
      fetcher.setRequestValue(appCheckToken, forHTTPHeaderField: Constants.appCheckTokenHeader)
    }

    // Override normal security rules if this is a local test.
    if emulatorOrigin != nil {
      fetcher.allowLocalhostRequest = true
      fetcher.allowedInsecureSchemes = ["http"]
    }

    fetcher.beginFetch { data, error in
      // If there was an HTTP error, convert it to our own error domain.
      var localError: Error?
      if let error = error as NSError? {
        if error.domain == kGTMSessionFetcherStatusDomain {
          localError = FunctionsErrorForResponse(
            status: error.code,
            body: data,
            serializer: self.serializer
          )
        } else if error.domain == NSURLErrorDomain, error.code == NSURLErrorTimedOut {
          localError = FunctionsErrorCode.deadlineExceeded.generatedError(userInfo: nil)
        }
        // If there was an error, report it to the user and stop.
        if let localError = localError {
          completion(.failure(localError))
        } else {
          completion(.failure(error))
        }
        return
      } else {
        // If there wasn't an HTTP error, see if there was an error in the body.
        if let bodyError = FunctionsErrorForResponse(
          status: 200,
          body: data,
          serializer: self.serializer
        ) {
          completion(.failure(bodyError))
          return
        }
      }

      // Porting: this check is new since we didn't previously check if `data` was nil.
      guard let data = data else {
        completion(.failure(FunctionsErrorCode.internal.generatedError(userInfo: nil)))
        return
      }

      let responseJSONObject: Any
      do {
        responseJSONObject = try JSONSerialization.jsonObject(with: data)
      } catch {
        completion(.failure(error))
        return
      }

      guard let responseJSON = responseJSONObject as? NSDictionary else {
        let userInfo = [NSLocalizedDescriptionKey: "Response was not a dictionary."]
        completion(.failure(FunctionsErrorCode.internal.generatedError(userInfo: userInfo)))
        return
      }

      // TODO(klimt): Allow "result" instead of "data" for now, for backwards compatibility.
      let dataJSON = responseJSON["data"] ?? responseJSON["result"]
      guard let dataJSON = dataJSON as AnyObject? else {
        let userInfo = [NSLocalizedDescriptionKey: "Response is missing data field."]
        completion(.failure(FunctionsErrorCode.internal.generatedError(userInfo: userInfo)))
        return
      }

      let resultData: Any?
      do {
        resultData = try self.serializer.decode(dataJSON)
      } catch {
        completion(.failure(error))
        return
      }

      // TODO: Force unwrap... gross
      let result = HTTPSCallableResult(data: resultData!)
      // TODO: This copied comment appears to be incorrect - it's impossible to have a nil callable result
      // If there's no result field, this will return nil, which is fine.
      completion(.success(result))
    }
  }
}
