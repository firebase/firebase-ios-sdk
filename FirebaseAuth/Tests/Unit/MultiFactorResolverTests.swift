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
import XCTest

@testable import FirebaseAuth
import FirebaseCore

#if os(iOS)
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class MultiFactorResolverTests: RPCBaseTests {
    static var auth: Auth?
    override class func setUp() {
      let kFakeAPIKey = "FAKE_API_KEY"
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.apiKey = kFakeAPIKey
      options.projectID = "myUserProjectID"
      FirebaseApp.configure(name: "test-mfaResolver", options: options)
      auth = Auth(
        app: FirebaseApp.app(name: "test-mfaResolver")!
      )
    }

    /** @fn testMultifactorResolverCreation
        @brief Tests successful creation of a @c FIRMultiFactorResolver object.
     */
    func testMultifactorResolverCreation() throws {
      let fakeMFAPendingCredential = "fakeMFAPendingCredential"
      MultiFactorResolverTests.auth?.tenantID = "tenant-id"
      let auth = try XCTUnwrap(MultiFactorResolverTests.auth)
      let resolver = MultiFactorResolver(with: fakeMFAPendingCredential,
                                         hints: [],
                                         auth: auth)
      XCTAssertEqual(resolver.auth, auth)
      XCTAssertEqual(resolver.hints, [])
      XCTAssertEqual(resolver.mfaPendingCredential, fakeMFAPendingCredential)
    }
  }
#endif
