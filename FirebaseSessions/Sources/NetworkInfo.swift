//
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
protocol NetworkInfoProtocol {
  var mobileCountryCode: String? { get }

  var mobileNetworkCode: String? { get }
}

class NetworkInfo: NetworkInfoProtocol {
  var mobileCountryCode: String? {
    // Don't look these up when in the simulator because they always fail
    // and put unnecessary logs in the customer's output
    #if targetEnvironment(simulator)
      return ""
    #else
      return FIRSESNetworkMobileCountryCode()
    #endif // targetEnvironment(simulator)
  }

  var mobileNetworkCode: String? {
    #if targetEnvironment(simulator)
      return ""
    #else
      return FIRSESNetworkMobileNetworkCode()
    #endif // targetEnvironment(simulator)
  }
}
