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

/// Sessions Subscriber is an interface that dependent SDKs
/// must implement.
@objc(FIRSessionsSubscriber)
public protocol SessionsSubscriber: Sendable {
  func onSessionChanged(_ session: SessionDetails)
  var isDataCollectionEnabled: Bool { get }
  var sessionsSubscriberName: SessionsSubscriberName { get }
}

/// Session Payload is a container for Session Data passed to Subscribers
/// whenever the Session changes
@objc(FIRSessionDetails)
public final class SessionDetails: NSObject, Sendable {
  @objc public let sessionId: String?

  public init(sessionId: String?) {
    self.sessionId = sessionId
    super.init()
  }
}

/// Session Subscriber Names are used for identifying subscribers
@objc(FIRSessionsSubscriberName)
public enum SessionsSubscriberName: Int, CustomStringConvertible, Sendable {
  case Unknown
  case Crashlytics
  case Performance

  public var description: String {
    switch self {
    case .Crashlytics:
      return "Crashlytics"
    case .Performance:
      return "Performance"
    default:
      return "Unknown"
    }
  }
}
