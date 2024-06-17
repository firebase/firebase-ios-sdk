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

/// The "getProjectConfig" endpoint.

private let kGetProjectConfigEndPoint = "getProjectConfig"

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class GetProjectConfigRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = GetProjectConfigResponse

  init(requestConfiguration: AuthRequestConfiguration) {
    requestConfiguration.httpMethod = "GET"
    super.init(endpoint: kGetProjectConfigEndPoint, requestConfiguration: requestConfiguration)
  }

  func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    // TODO: Probably nicer to throw, but what should we throw?
    fatalError()
  }

  override var containsPostBody: Bool { return false }
}
