// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License")
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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AuthWebUtilsTests: XCTestCase {
  /** @fn testExtractDomainWithHTTP
   @brief Test case for extracting the domain from a URL with "http://" scheme.
   */
  func testExtractDomainWithHTTP() {
    let urlString = "http://www.example.com/path/to/resource"
    let domain = AuthWebUtils.extractDomain(urlString: urlString)
    XCTAssertEqual(domain, "www.example.com")
  }

  /** @fn testExtractDomainWithHTTPS
   @brief Test case for extracting the domain from a URL with "https://" scheme.
   */
  func testExtractDomainWithHTTPS() {
    let urlString = "https://www.example.com/path/to/resource/"
    let domain = AuthWebUtils.extractDomain(urlString: urlString)
    XCTAssertEqual(domain, "www.example.com")
  }

  /** @fn testExtractDomainWithoutScheme
   @brief Test case for extracting the domain from a URL without a scheme (assumes HTTP by default).
   */
  func testExtractDomainWithoutScheme() {
    let urlString = "www.example.com/path/to/resource"
    let domain = AuthWebUtils.extractDomain(urlString: urlString)
    XCTAssertEqual(domain, "www.example.com")
  }

  /** @fn testExtractDomainWithTrailingSlashes
   @brief Test case for extracting the domain from a URL with trailing slashes.
   */
  func testExtractDomainWithTrailingSlashes() {
    let urlString = "http://www.example.com//////"
    let domain = AuthWebUtils.extractDomain(urlString: urlString)
    XCTAssertEqual(domain, "www.example.com")
  }

  /** @fn testExtractDomainWithStringDomain
   @brief Test case for extracting the domain from a string that represents just the domain itself.
   */
  func testExtractDomainWithStringDomain() {
    let urlString = "example.com"
    let domain = AuthWebUtils.extractDomain(urlString: urlString)
    XCTAssertEqual(domain, "example.com")
  }
}
