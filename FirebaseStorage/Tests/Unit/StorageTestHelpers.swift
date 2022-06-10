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

@testable import FirebaseStorage
import FirebaseCore
import FirebaseStorageInternal

import XCTest

class StorageTestHelpers: XCTestCase {

  internal func storage() -> FIRIMPLStorage {
    return FIRIMPLStorage(app: FirebaseApp.app()!, bucket: "bucket", auth: nil, appCheck: nil)
  }

  override class func setUp() {
    super.setUp()
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "myProjectID"
    FirebaseApp.configure(options: options)
  }

  internal func rootReference() -> FIRIMPLStorageReference {
    let path = FIRStoragePath(bucket: "bucket", object: nil)
    return FIRIMPLStorageReference(storage: self.storage(), path: path)
  }

  internal func waitForExpectation(test: XCTest) {
    waitForExpectations(timeout: 10) { (error) in
      if let error = error {
        print("Error \(error)")
      }
    }
  }

  private func successBlock(witMetadata metadata: FIRIMPLStorageMetadata? = nil) -> GTMSessionFetcherTestBlock {
    var data: Data?
    if let metadata = metadata {
      data = try? JSONSerialization.data(withJSONObject:metadata.dictionaryRepresentation())
    }
    return self.block(forData: data, url: nil, statusCode:200)
  }

  internal func successBlock(withURLString url: String) -> GTMSessionFetcherTestBlock {
    let data = "{}".data(using: .utf8)
    return self.block(forData: data, url: url, statusCode:200)
  }

  internal func unauthenticatedBlock() -> GTMSessionFetcherTestBlock {
    let unauthenticatedString =
    "<html><body><p>User not authenticated. Authentication via Authorization header required. " +
    "Authorization Header does not match expected format of 'Authorization: Firebase " +
    "<JWT>'.</p></body></html>";
    let data = unauthenticatedString.data(using: .utf8)
    return self.block(forData: data, url: nil, statusCode:401)
  }

  internal func unauthorizedBlock() -> GTMSessionFetcherTestBlock {
    let unauthorizedString =
    "<html><body><p>User not authorized. Authentication via Authorization header required. " +
    "Authorization Header does not match expected format of 'Authorization: Firebase " +
    "<JWT>'.</p></body></html>";
    let data = unauthorizedString.data(using: .utf8)
    return self.block(forData: data, url: nil, statusCode:403)
  }

  internal func notFoundBlock() -> GTMSessionFetcherTestBlock {
    let unauthenticatedString = "<html><body><p>Object not found.</p></body></html>"
    let data = unauthenticatedString.data(using: .utf8)
    return self.block(forData: data, url: nil, statusCode:404)
  }

  private func block(forData data:Data?, url: String?, statusCode code: Int) -> GTMSessionFetcherTestBlock {
    let block = { (fetcher: GTMSessionFetcher, response: GTMSessionFetcherTestResponse) in
      let fetcherURL = fetcher.request?.url!
    if let url = url {
      XCTAssertEqual(url, fetcherURL?.absoluteString)
    }
      let httpResponse = HTTPURLResponse(url: fetcherURL!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: nil)
    var error: NSError?
    if code >= 400 {
      var userInfo: [String: Any]?
      if let data = data {
        userInfo = ["data": data]
      }
      error = NSError(domain: "com.google.HTTPStatus", code: code, userInfo: userInfo)
    }
    response(httpResponse, data, error)
    }
    return block
  }


  private let objectString = "https://firebasestorage.googleapis.com:443/v0/b/bucket/o/object"

  internal func objectURL() -> URL {
    return URL(string: objectString)!
  }

  internal func objectPath() -> FIRStoragePath {
    return FIRStoragePath(from: objectString)!
  }
}
