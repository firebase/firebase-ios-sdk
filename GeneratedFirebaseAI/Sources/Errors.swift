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

#if os(Linux)
  import FoundationNetworking
#endif

/// Errors that signify something is wrong in either our implementation or the AI Logic SDK.
public enum InternalError: Error, Sendable {
  case MethodNotSupportedForGoogleAI
  case MethodNotSupportedForVertexAI
  case UnsupportedParameter(parameter: String, backend: Backend)
  case InvalidURL(url: String)
  case InvalidURLQueryItems(url: String, queryItems: [URLQueryItem])
  case UnsupportedTransformerCalled(transformer: String)
  case InvalidTypeInTransformer(field: String, expectedType: String)
  case MissingExpectedFieldInTransformer(field: String)
}

/// Errors regarding the network and backend
public enum BackendErrors: Error, Sendable {
  case RPCError(
    responseCode: Int, message: String?, status: String?, details: [[String: JSONValue]]
  )
  case FailedToParseResponse(data: Data, cause: Error)
  case NonHTTPResponse(response: URLResponse)
  case UnrecognizedError(responseCode: Int, data: Data, cause: Error)
}

/// Generic errors that should probably be translated for consumers
public enum CommonErrors: Error, Sendable {
  case MissingFirebaseAPIKey(appName: String)
  case MissingFirebaseProjectID(appName: String)
  case MissingGetLimitedUseTokenFunction
  case EmptyModelName
  case InvalidSymbolsInModelName(name: String)
}

/// RPC error from any of the backends.
public struct RPCError: Sendable, Decodable {
  public struct Error: Sendable, Decodable {
    public let code: Int32?
    public let status: String?
    public let details: [[String: JSONValue]]?
    public let message: String?
  }

  let error: Error

  func toBackendError(responseCode: Int) -> BackendErrors {
    BackendErrors.RPCError(
      responseCode: responseCode,
      message: error.message,
      status: error.status,
      details: error.details ?? []
    )
  }
}
