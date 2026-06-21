// Copyright 2020 Google LLC
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

class MockURLProtocol: URLProtocol {
  nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (
    Data,
    HTTPURLResponse
  ))?

  override class func canInit(with request: URLRequest) -> Bool {
    #if os(watchOS)
      print("MockURLProtocol cannot be used on watchOS.")
      return false
    #else
      return true
    #endif // os(watchOS)
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    guard let requestHandler = MockURLProtocol.requestHandler else {
      fatalError("`requestHandler` is nil.")
    }
    guard let client = client else {
      fatalError("`client` is nil.")
    }

    do {
      let (data, respopnse) = try requestHandler(request)
      client.urlProtocol(self, didReceive: respopnse, cacheStoragePolicy: .notAllowed)
      client.urlProtocol(self, didLoad: data)
      client.urlProtocolDidFinishLoading(self)
    } catch {
      client.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
