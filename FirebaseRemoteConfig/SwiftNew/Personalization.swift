// Copyright 2024 Google LLC
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

// TODO: AnalyticInterop refactor
// import FirebaseAnalyticsInterop

private let kAnalyticsOriginPersonalization = "fp"
private let kExternalEvent = "personalization_assignment"
private let kExternalRcParameterParam = "arm_key"
private let kExternalArmValueParam = "arm_value"
private let kPersonalizationId = "personalizationId"
private let kExternalPersonalizationIdParam = "personalization_id"
private let kArmIndex = "armIndex"
private let kExternalArmIndexParam = "arm_index"
private let kGroup = "group"
private let kExternalGroupParam = "group"

private let kInternalEvent = "_fpc"
private let kChoiceId = "choiceId"
private let kInternalChoiceIdParam = "_fpid"

@objc(RCNPersonalization)
public class Personalization: NSObject {
  /// Analytics connector.
  weak var analytics: FIRAnalyticsInterop?

  private var loggedChoiceIds = [String: String]()

  /// Designated initializer.
  @objc public init(analytics: FIRAnalyticsInterop?) {
    self.analytics = analytics
    super.init()
  }

  /// Called when an arm is pulled from Remote Config. If the arm is personalized, log information
  /// to
  /// Google Analytics in another thread.
  @objc public func logArmActive(rcParameter: String, config: [String: Any]) {
    guard let ids =
      config[ConfigConstants.fetchResponseKeyPersonalizationMetadata] as? [String: Any],
      let values = config[ConfigConstants.fetchResponseKeyEntries] as? [String: RemoteConfigValue],
      let value = values[rcParameter] else {
      return
    }

    guard let metadata = ids[rcParameter] as? [String: AnyHashable],
          let choiceId = metadata[kChoiceId] as? String else {
      return
    }

    // Listeners like logArmActive() are dispatched to a serial queue, so loggedChoiceIds should
    // contain any previously logged RC parameter / choice ID pairs.
    if loggedChoiceIds[rcParameter] == choiceId {
      return
    }
    loggedChoiceIds[rcParameter] = choiceId

    analytics?.logEvent(
      withOrigin: kAnalyticsOriginPersonalization,
      name: kExternalEvent,
      parameters: [
        kExternalRcParameterParam: rcParameter,
        kExternalArmValueParam: value.stringValue,
        kExternalPersonalizationIdParam: metadata[kPersonalizationId] ?? "",
        // Provide default value if nil
        kExternalArmIndexParam: metadata[kArmIndex] ?? "", // Provide default value if nil
        kExternalGroupParam: metadata[kGroup] ?? "", // Provide default value if nil
      ]
    )

    analytics?.logEvent(withOrigin: kAnalyticsOriginPersonalization,
                        name: kInternalEvent,
                        parameters: [kInternalChoiceIdParam: choiceId])
  }
}
