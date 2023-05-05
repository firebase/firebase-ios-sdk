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

/** @var kGetProjectConfigEndPoint
    @brief The "getProjectConfig" endpoint.
 */
private let kGetProjectConfigEndPoint = "getProjectConfig"

public class GetProjectConfigRequest_NEW_:  IdentityToolkitRequest, AuthRPCRequest_NEW_ {
  /// The corresponding response for this request.
  public var response: GetProjectConfigResponse_NEW_ = GetProjectConfigResponse_NEW_()

  public init(requestConfiguration: AuthRequestConfiguration) {
    super.init(endpoint: kGetProjectConfigEndPoint, requestConfiguration: requestConfiguration)
  }

  override public func requestURL() -> URL {
    return URL(string: "")!
  }

  public func unencodedHTTPRequestBody() throws -> [String : AnyHashable] {
    // TODO: Probably nicer to throw, but what should we throw?
    fatalError()
  }

  override public func requestConfiguration() -> AuthRequestConfiguration {
    // TODO: Figure it out
    fatalError()
  }

  public var containsPostBody: Bool { false }
}
