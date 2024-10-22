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

#if SWIFT_PACKAGE
  import RemoteConfigFakeConsoleObjC
#endif

// Create a partial mock by subclassing the URLSessionDataTask.
class URLSessionDataTaskMock: URLSessionDataTask, @unchecked Sendable {
  private let closure: () -> Void

  init(closure: @escaping () -> Void) {
    self.closure = closure
  }

  override func resume() {
    closure()
  }
}

class URLSessionMock: URLSession, @unchecked Sendable {
  typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void

  private let fakeConsole: FakeConsole
  init(with fakeConsole: FakeConsole) {
    self.fakeConsole = fakeConsole
  }

  // Properties to control what gets returned to the URLSession callback.
  // error could also be added here.
  var data: Data?
  var response: URLResponse?
  var etag = ""

  override func dataTask(with request: URLRequest,
                         completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void)
    -> URLSessionDataTask {
    let consoleValues = fakeConsole.get()
    if etag == "" || consoleValues["state"] as! String == RCNFetchResponseKeyStateUpdate {
      // Time string in microseconds to insure a different string from previous change.
      etag = String(NSDate().timeIntervalSince1970)
    }
    let jsonData = try! JSONSerialization.data(withJSONObject: consoleValues)
    let response = HTTPURLResponse(url: URL(fileURLWithPath: "fakeURL"),
                                   statusCode: 200,
                                   httpVersion: nil,
                                   headerFields: ["etag": etag])
    return URLSessionDataTaskMock {
      completionHandler(jsonData, response, nil)
    }
  }
}
