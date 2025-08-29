// Copyright 2025 Google LLC
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
import Foundation
import XCTest

@testable import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
enum GenerativeModelTestUtil {
  /// Returns an HTTP request handler
  static func httpRequestHandler(forResource name: String,
                                 withExtension ext: String,
                                 subdirectory subpath: String,
                                 statusCode: Int = 200,
                                 timeout: TimeInterval = RequestOptions().timeout,
                                 appCheckToken: String? = nil,
                                 authToken: String? = nil,
                                 dataCollection: Bool = true) throws -> ((URLRequest) throws -> (
    URLResponse,
    AsyncLineSequence<URL.AsyncBytes>?
  )) {
    // Skip tests using MockURLProtocol on watchOS; unsupported in watchOS 2 and later, see
    // https://developer.apple.com/documentation/foundation/urlprotocol for details.
    #if os(watchOS)
      throw XCTSkip("Custom URL protocols are unsupported in watchOS 2 and later.")
    #else // os(watchOS)
      let bundle = BundleTestUtil.bundle()
      let fileURL = try XCTUnwrap(
        bundle.url(forResource: name, withExtension: ext, subdirectory: subpath)
      )
      return { request in
        let requestURL = try XCTUnwrap(request.url)
        XCTAssertEqual(requestURL.path.occurrenceCount(of: "models/"), 1)
        XCTAssertEqual(request.timeoutInterval, timeout)
        let apiClientTags = try XCTUnwrap(request.value(forHTTPHeaderField: "x-goog-api-client"))
          .components(separatedBy: " ")
        XCTAssert(apiClientTags.contains(GenerativeAIService.languageTag))
        XCTAssert(apiClientTags.contains(GenerativeAIService.firebaseVersionTag))
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"), appCheckToken)

        let firebaseAppID = request.value(forHTTPHeaderField: "X-Firebase-AppId")
        let appVersion = request.value(forHTTPHeaderField: "X-Firebase-AppVersion")
        let expectedAppVersion =
          try? XCTUnwrap(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        XCTAssertEqual(firebaseAppID, dataCollection ? "My app ID" : nil)
        XCTAssertEqual(appVersion, dataCollection ? expectedAppVersion : nil)

        if let authToken {
          XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Firebase \(authToken)"
          )
        } else {
          XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        }
        let response = try XCTUnwrap(HTTPURLResponse(
          url: requestURL,
          statusCode: statusCode,
          httpVersion: nil,
          headerFields: nil
        ))
        return (response, fileURL.lines)
      }
    #endif // os(watchOS)
  }

  static func nonHTTPRequestHandler() throws -> ((URLRequest) -> (
    URLResponse,
    AsyncLineSequence<URL.AsyncBytes>?
  )) {
    // Skip tests using MockURLProtocol on watchOS; unsupported in watchOS 2 and later, see
    // https://developer.apple.com/documentation/foundation/urlprotocol for details.
    #if os(watchOS)
      throw XCTSkip("Custom URL protocols are unsupported in watchOS 2 and later.")
    #else // os(watchOS)
      return { request in
        // This is *not* an HTTPURLResponse
        let response = URLResponse(
          url: request.url!,
          mimeType: nil,
          expectedContentLength: 0,
          textEncodingName: nil
        )
        return (response, nil)
      }
    #endif // os(watchOS)
  }

  static func testFirebaseInfo(appCheck: AppCheckInterop? = nil,
                               auth: AuthInterop? = nil,
                               privateAppID: Bool = false,
                               useLimitedUseAppCheckTokens: Bool = false) -> FirebaseInfo {
    let app = FirebaseApp(instanceWithName: "testApp",
                          options: FirebaseOptions(googleAppID: "ignore",
                                                   gcmSenderID: "ignore"))
    app.isDataCollectionDefaultEnabled = !privateAppID
    return FirebaseInfo(
      appCheck: appCheck,
      auth: auth,
      projectID: "my-project-id",
      apiKey: "API_KEY",
      firebaseAppID: "My app ID",
      firebaseApp: app,
      useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens
    )
  }
}

private extension String {
  /// Returns the number of occurrences of `substring` in the `String`.
  func occurrenceCount(of substring: String) -> Int {
    return components(separatedBy: substring).count - 1
  }
}
