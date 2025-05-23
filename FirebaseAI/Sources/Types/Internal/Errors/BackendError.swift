// Copyright 2023 Google LLC
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

struct BackendError: Error {
  let httpResponseCode: Int
  let message: String
  let status: RPCStatus
  let details: [ErrorDetails]

  private var errorInfo: ErrorDetails? {
    return details.first { $0.isErrorInfo() }
  }

  init(httpResponseCode: Int, message: String, status: RPCStatus, details: [ErrorDetails]) {
    self.httpResponseCode = httpResponseCode
    self.message = message
    self.status = status
    self.details = details
  }

  func isVertexAIInFirebaseServiceDisabledError() -> Bool {
    return details.contains { $0.isVertexAIInFirebaseServiceDisabledErrorDetails() }
  }
}

// MARK: - CustomNSError Conformance

extension BackendError: CustomNSError {
  public static var errorDomain: String {
    return "\(Constants.baseErrorDomain).\(Self.self)"
  }

  var errorCode: Int {
    return httpResponseCode
  }

  var errorUserInfo: [String: Any] {
    return [
      NSLocalizedDescriptionKey:
        "\(message) (\(Self.errorDomain) - HTTP \(httpResponseCode) \(status.rawValue))",
    ]
  }
}

// MARK: - Decodable Conformance

extension BackendError: Decodable {
  enum CodingKeys: CodingKey {
    case error
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let status = try container.decode(ErrorStatus.self, forKey: .error)

    if let code = status.code {
      httpResponseCode = code
    } else {
      httpResponseCode = -1
    }

    if let message = status.message {
      self.message = message
    } else {
      message = "Unknown error."
    }

    if let rpcStatus = status.status {
      self.status = rpcStatus
    } else {
      self.status = .unknown
    }

    details = status.details
  }
}
