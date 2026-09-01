// Copyright 2026 Google LLC
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
import SharedDataModels
import Testing

@testable import GeminiAPIClient

@Suite("GeminiAPIError Tests")
struct GeminiAPIErrorTests {
  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func retryInfoDecodingAndDurationCalculation() throws {
    let json = """
      {
        "error": {
          "code": 429,
          "message": "Resource exhausted",
          "status": "RESOURCE_EXHAUSTED",
          "details": [
            {
              "@type": "type.googleapis.com/google.rpc.RetryInfo",
              "retryDelay": "12.5s"
            }
          ]
        }
      }
      """

    let error = try JSONDecoder().decode(GoogleCloudAPIError.self, from: Data(json.utf8))

    #expect(error.retryDelay == .seconds(12.5))
    #expect(error.code == 429)
    #expect(error.status == .resourceExhausted)
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func geminiAPIErrorRetryAfterPrecedence() {
    let cloudErrorWithDelay = GoogleCloudAPIError(
      code: 429,
      message: "Quota exceeded",
      status: .resourceExhausted,
      details: [.retryInfo(GoogleCloudAPIError.RetryInfo(retryDelay: "30s"))]
    )

    let apiErrorWithOverride = GeminiAPIError.apiError(
      cloudErrorWithDelay.withRetryDelay(.seconds(60)))
    let apiErrorWithoutOverride = GeminiAPIError.apiError(cloudErrorWithDelay)
    let httpError = GeminiAPIError.httpError(statusCode: 500, body: "Server error")

    #expect(apiErrorWithOverride.retryAfter == .seconds(60))
    #expect(apiErrorWithoutOverride.retryAfter == .seconds(30))
    #expect(httpError.retryAfter == nil)
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func localizedErrorAndCustomNSErrorProperties() {
    let cloudError = GoogleCloudAPIError(
      code: 400,
      message: "Invalid argument message",
      status: .invalidArgument,
      details: [
        .localizedMessage(
          GoogleCloudAPIError.LocalizedMessage(
            locale: "en-US", message: "Localized argument error")),
        .help(
          GoogleCloudAPIError.Help(links: [
            GoogleCloudAPIError.Help.Link(
              description: "Help doc", url: "https://cloud.google.com/help")
          ])),
      ],
      retryDelay: .seconds(15)
    )

    let apiError = GeminiAPIError.apiError(cloudError)
    let httpError = GeminiAPIError.httpError(statusCode: 503, body: "Service unavailable")

    #expect(apiError.errorDescription == "Localized argument error")
    #expect(apiError.failureReason == "INVALID_ARGUMENT")
    #expect(apiError.helpAnchor == "https://cloud.google.com/help")
    #expect(apiError.errorCode == 400)
    #expect(GeminiAPIError.errorDomain == "GeminiAPIClient.GeminiAPIError")
    #expect(apiError.errorUserInfo["code"] as? Int == 400)
    #expect(apiError.errorUserInfo["status"] as? String == "INVALID_ARGUMENT")
    #expect(apiError.errorUserInfo["retryAfterSeconds"] as? Double == 15.0)

    #expect(httpError.errorDescription == "HTTP 503: Service unavailable")
    #expect(httpError.failureReason == "HTTP status 503")
    #expect(httpError.helpAnchor == nil)
    #expect(httpError.errorCode == 503)
    #expect(httpError.errorUserInfo["statusCode"] as? Int == 503)
    #expect(httpError.errorUserInfo["body"] as? String == "Service unavailable")
  }
}
