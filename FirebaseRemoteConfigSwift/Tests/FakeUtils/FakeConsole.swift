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

#if SWIFT_PACKAGE
  import RemoteConfigFakeConsoleObjC
#endif

class FakeConsole {
  var config = [String: AnyHashable]()
  private var last = [String: AnyHashable]()

  init() {
    config = [String: AnyHashable]()
  }

  func empty() {
    config = [String: AnyHashable]()
  }

  func get() -> [String: AnyHashable] {
    if config.count == 0 {
      last = config
      return [RCNFetchResponseKeyState: RCNFetchResponseKeyStateEmptyConfig]
    }
    var state = RCNFetchResponseKeyStateNoChange
    if last != config {
      state = RCNFetchResponseKeyStateUpdate
    }
    last = config
    return [RCNFetchResponseKeyState: state, RCNFetchResponseKeyEntries: config]
  }
}
