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
import FirebaseCore
import FirebaseSharedSwift
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

// PLACEHOLDERS
protocol AuthInterop {
  func getToken(forcingRefresh: Bool, callback: (Result<String, Error>) -> Void)
}

protocol MessagingInterop {
  var fcmToken: String { get }
}

protocol AppCheckInterop {
  func getToken(forcingRefresh: Bool, callback: (Result<String, Error>) -> Void)
}

// END PLACEHOLDERS

private enum Constants {
  static let appCheckTokenHeader = "X-Firebase-AppCheck"
  static let fcmTokenHeader = "Firebase-Instance-ID-Token"
}

/**
 * `Functions` is the client for Cloud Functions for a Firebase project.
 */
@objc public class Functions: NSObject {
  // MARK: - Private Variables

  /// The network client to use for http requests.
  private let fetcherService: GTMSessionFetcherService
  // The projectID to use for all function references.
  private let projectID: String
  // The region to use for all function references.
  private let region: String
  // The custom domain to use for all functions references (optional).
  private let customDomain: String?
  // A serializer to encode/decode data and return values.
  private let serializer = FUNSerializer()
  // A factory for getting the metadata to include with function calls.
  private let contextProvider: FunctionsContextProvider

  /**
   * The current emulator origin, or nil if it is not set.
   */
  public private(set) var emulatorOrigin: String?

  /**
   * Creates a Cloud Functions client with the given app and region, or returns a pre-existing
   * instance if one already exists.
   * @param app The app for the Firebase project.
   * @param region The region for the http trigger, such as "us-central1".
   */
  public class func functions(app: FirebaseApp = FirebaseApp.app()!,
                              region: String = "us-central1") -> Functions {
    return Functions(app: app, region: region, customDomain: nil)
  }

  /**
   * Creates a Cloud Functions client with the given app and region, or returns a pre-existing
   * instance if one already exists.
   * @param app The app for the Firebase project.
   * @param customDomain A custom domain for the http trigger, such as "https://mydomain.com".
   */
  public class func functions(app: FirebaseApp = FirebaseApp.app()!,
                              customDomain: String) -> Functions {
    return Functions(app: app, region: "us-central1", customDomain: customDomain)
  }

  internal convenience init(app: FirebaseApp,
                            region: String,
                            customDomain: String?) {
    #warning("Should be fetched from the App's component container instead.")
    /*
     id<FIRFunctionsProvider> provider = FIR_COMPONENT(FIRFunctionsProvider, app.container);
     return [provider functionsForApp:app region:region customDomain:customDomain type:[self class]];
     */
    self.init(projectID: app.options.projectID!,
              region: region,
              customDomain: customDomain,
              // TODO: Get this out of the app.
              auth: nil,
              messaging: nil,
              appCheck: nil)
  }

  internal init(projectID: String,
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

  /**
   * Creates a reference to the Callable HTTPS trigger with the given name.
   * @param name The name of the Callable HTTPS trigger.
   */
  public func httpsCallable(_ name: String) -> HTTPSCallable {
    return HTTPSCallable(functions: self, name: name)
  }

  /// Creates a reference to the Callable HTTPS trigger with the given name, the type of an `Encodable`
  /// request and the type of a `Decodable` response.
  /// - Parameter name: The name of the Callable HTTPS trigger
  /// - Parameter requestAs: The type of the `Encodable` entity to use for requests to this `Callable`
  /// - Parameter responseAs: The type of the `Decodable` entity to use for responses from this `Callable`
  /// - Parameter encoder: The encoder instance to use to run the encoding.
  /// - Parameter decoder: The decoder instance to use to run the decoding.
  public func httpsCallable<Request: Encodable,
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

  /**
   * Changes this instance to point to a Cloud Functions emulator running locally.
   * See https://firebase.google.com/docs/functions/local-emulator
   * @param host The host of the local emulator, such as "localhost".
   * @param port The port of the local emulator, for example 5005.
   */
  public func useEmulator(withHost host: String, port: Int) {
    let prefix = host.hasPrefix("http") ? "" : "http://"
    let origin = String(format: "\(prefix)\(host):%li", port)
    emulatorOrigin = origin
  }

  // MARK: - Private Funcs

  private func urlWithName(_ name: String) -> String {
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
        self.callFunction(name: name,
                          withObject: data,
                          timeout: timeout,
                          context: context,
                          completion: completion)
      }
    }
  }

  private func callFunction(name: String,
                            withObject data: Any?,
                            timeout: TimeInterval,
                            context: FunctionsContext,
                            completion: @escaping ((Result<HTTPSCallableResult, Error>) -> Void)) {
    let url = URL(string: urlWithName(name))!
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
      } else {
        // If there wasn't an HTTP error, see if there was an error in the body.
        localError = FunctionsErrorForResponse(status: 200, body: data, serializer: self.serializer)
      }

      // If there was an error, report it to the user and stop.
      if let localError = localError {
        completion(.failure(localError))
        return
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
      #warning(
        "This copied comment appears to be incorrect - it's impossible to have a nil callable result."
      )
      // If there's no result field, this will return nil, which is fine.
      completion(.success(result))
    }
  }
}
