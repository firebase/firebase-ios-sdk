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

/// Creates the errors that Firebase SDKs report for HTTP responses with a status code of 300 or
/// more.
///
/// The domain, code, and `userInfo` keys are the ones that Firebase SDKs have always used for
/// unsuccessful HTTP responses, so apps that inspect these errors keep working.
public enum HTTPStatusError {
  /// The error domain.
  public static let domain = "com.google.HTTPStatus"

  /// The `userInfo` key for the response body.
  public static let dataKey = "data"

  /// The `userInfo` key for the value of the response's `Content-Type` header.
  public static let contentTypeKey = "data_content_type"

  /// Returns `nil` if the status code is below 300. Otherwise returns an error whose code is the
  /// status code. Its `userInfo` holds the body and its content type only when the body isn't
  /// empty.
  public static func error(for response: HTTPURLResponse, body: Data) -> NSError? {
    guard response.statusCode >= 300 else {
      return nil
    }
    var userInfo: [String: Any] = [:]
    if !body.isEmpty {
      userInfo[dataKey] = body
      if let contentType = response.value(forHTTPHeaderField: "Content-Type") {
        userInfo[contentTypeKey] = contentType
      }
    }
    return NSError(domain: domain, code: response.statusCode,
                   userInfo: userInfo.isEmpty ? nil : userInfo)
  }
}
