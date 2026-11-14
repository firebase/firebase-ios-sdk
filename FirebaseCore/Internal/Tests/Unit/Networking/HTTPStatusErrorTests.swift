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

@testable import FirebaseCoreInternal
import XCTest

class HTTPStatusErrorTests: XCTestCase {
  private let url = URL(string: "https://example.com/resource")!

  func testSuccessfulStatusCodesHaveNoError() {
    for status in [200, 201, 204, 299] {
      XCTAssertNil(HTTPStatusError.error(for: response(status: status), body: Data("x".utf8)),
                   "HTTP \(status)")
    }
  }

  func testUnsuccessfulStatusCodesHaveAnError() throws {
    for status in [300, 304, 400, 404, 500, 503] {
      let error = try XCTUnwrap(HTTPStatusError.error(for: response(status: status), body: Data()))
      XCTAssertEqual(error.domain, "com.google.HTTPStatus", "HTTP \(status)")
      XCTAssertEqual(error.code, status)
    }
  }

  func testErrorWithBodyIncludesBodyAndContentType() throws {
    let body = Data(#"{"error":"denied"}"#.utf8)
    let error = try XCTUnwrap(HTTPStatusError.error(
      for: response(status: 403, headers: ["content-type": "application/json"]),
      body: body
    ))

    XCTAssertEqual(error.userInfo.count, 2)
    XCTAssertEqual(error.userInfo["data"] as? Data, body)
    XCTAssertEqual(error.userInfo["data_content_type"] as? String, "application/json")
  }

  func testErrorWithBodyButNoContentTypeIncludesOnlyBody() throws {
    let body = Data("denied".utf8)
    let error = try XCTUnwrap(HTTPStatusError.error(for: response(status: 403), body: body))

    XCTAssertEqual(error.userInfo.count, 1)
    XCTAssertEqual(error.userInfo[HTTPStatusError.dataKey] as? Data, body)
  }

  func testErrorWithEmptyBodyHasNoUserInfo() throws {
    let error = try XCTUnwrap(HTTPStatusError.error(
      for: response(status: 500, headers: ["Content-Type": "text/plain"]),
      body: Data()
    ))

    XCTAssertTrue(error.userInfo.isEmpty)
  }

  private func response(status: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
  }
}
