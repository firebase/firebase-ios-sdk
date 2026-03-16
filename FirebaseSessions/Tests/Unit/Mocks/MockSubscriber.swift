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

import FirebaseCoreInternal
@testable import FirebaseSessions
import Foundation

final class MockSubscriber: SessionsSubscriber, Sendable {
  let sessionsSubscriberName: FirebaseSessions.SessionsSubscriberName

  var sessionThatChanged: FirebaseSessions.SessionDetails? {
    get { _sessionThatChanged.value() }
    set { _sessionThatChanged.withLock { $0 = newValue } }
  }

  var isDataCollectionEnabled: Bool {
    get { _isDataCollectionEnabled.value() }
    set { _isDataCollectionEnabled.withLock { $0 = newValue } }
  }

  private let _sessionThatChanged = UnfairLock<FirebaseSessions.SessionDetails?>(nil)
  private let _isDataCollectionEnabled = UnfairLock<Bool>(true)

  init(name: SessionsSubscriberName) {
    sessionsSubscriberName = name
  }

  func onSessionChanged(_ session: FirebaseSessions.SessionDetails) {
    _sessionThatChanged.withLock { $0 = session }
  }
}
