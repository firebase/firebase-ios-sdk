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

import FirebaseRemoteConfigInterop
import XCTest

class MockRCInterop: RemoteConfigInterop {
  weak var subscriber: FirebaseRemoteConfigInterop.RolloutsStateSubscriber?
  func registerRolloutsStateSubscriber(_ subscriber: FirebaseRemoteConfigInterop
    .RolloutsStateSubscriber,
    for namespace: String) {
    self.subscriber = subscriber
  }
}

class MockRolloutSubscriber: RolloutsStateSubscriber {
  var isSubscriberCalled = false
  var rolloutsState: RolloutsState?
  func rolloutsStateDidChange(_ rolloutsState: FirebaseRemoteConfigInterop.RolloutsState) {
    isSubscriberCalled = true
    self.rolloutsState = rolloutsState
  }
}

final class RemoteConfigInteropTests: XCTestCase {
  let rollouts: RolloutsState = {
    let assignment1 = RolloutAssignment(
      rolloutId: "rollout_1",
      variantId: "control",
      templateVersion: 1,
      parameterKey: "my_feature",
      parameterValue: "false"
    )
    let assignment2 = RolloutAssignment(
      rolloutId: "rollout_2",
      variantId: "enabled",
      templateVersion: 123,
      parameterKey: "themis_big_feature",
      parameterValue: "1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111"
    )
    let rollouts = RolloutsState(assignmentList: [assignment1, assignment2])
    return rollouts
  }()

  func testRemoteConfigIntegration() throws {
    let rcSubscriber = MockRolloutSubscriber()
    let rcInterop = MockRCInterop()
    rcInterop.registerRolloutsStateSubscriber(rcSubscriber, for: "namespace")
    rcInterop.subscriber?.rolloutsStateDidChange(rollouts)

    XCTAssertTrue(rcSubscriber.isSubscriberCalled)
    XCTAssertEqual(rcSubscriber.rolloutsState?.assignments.count, 2)
  }
}
