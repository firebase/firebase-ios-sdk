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

import FirebaseABTesting
import Foundation

// TODO(ncooke3): Once everything is ported, the `@objc` and `public` access
// can be removed.

/// Handles experiment information update and persistence.
@objc(RCNConfigExperiment) open class ConfigExperiment: NSObject {
  private static let experimentMetadataKeyLastStartTime = "last_experiment_start_time"
  private static let serviceOrigin = "frc"

  @objc private var experimentPayloads: [Data]
  @objc private var experimentMetadata: [String: Any]
  @objc private var activeExperimentPayloads: [Data]
  private let dbManager: ConfigDBManager
  // TODO(ncooke3): This property could be made non-optional after ensuring the
  // unit tests properly configure the default app. This is because the
  // experiment controller comes from the ABTesting component.
  private let experimentController: ExperimentController?
  private let experimentStartTimeDateFormatter: DateFormatter

  /// Designated initializer;
  @objc public init(dbManager: ConfigDBManager,
                    experimentController controller: ExperimentController?) {
    experimentPayloads = []
    experimentMetadata = [:]
    activeExperimentPayloads = []
    experimentStartTimeDateFormatter = {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
      // Locale needs to be hardcoded. See
      // https://developer.apple.com/library/ios/#qa/qa1480/_index.html for more details.
      dateFormatter.locale = Locale(identifier: "en_US_POSIX")
      dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
      return dateFormatter
    }()
    self.dbManager = dbManager
    experimentController = controller
    super.init()
    loadExperimentFromTable()
  }

  @objc private func loadExperimentFromTable() {
    let completionHandler: (Bool, [String: Any]?) -> Void = { [weak self] _, result in
      guard let self else { return }

      if result?[ConfigConstants.experimentTableKeyPayload] != nil {
        self.experimentPayloads.removeAll()
        if let experiments = result?[ConfigConstants.experimentTableKeyPayload] as? [Data] {
          for experiment in experiments {
            do {
              try JSONSerialization.jsonObject(with: experiment)
              self.experimentPayloads.append(experiment)
            } catch {
              RCLog.warning("I-RCN000031", "Experiment payload could not be parsed as JSON.")
            }
          }
        }
      }

      if let experimentTable =
        result?[ConfigConstants.experimentTableKeyMetadata] as? [String: Any] {
        self.experimentMetadata = experimentTable
      }

      if result?[ConfigConstants.experimentTableKeyActivePayload] != nil {
        self.activeExperimentPayloads.removeAll()
        if let experiments = result?[ConfigConstants.experimentTableKeyActivePayload] as? [Data] {
          for experiment in experiments {
            do {
              try JSONSerialization.jsonObject(with: experiment)
              self.activeExperimentPayloads.append(experiment)
            } catch {
              RCLog.warning(
                "I-RCN000031",
                "Activated experiment payload could not be parsed as JSON."
              )
            }
          }
        }
      }
    }

    dbManager.loadExperiment(completionHandler: completionHandler)
  }

  /// Update/Persist experiment information from config fetch response.
  @objc public func updateExperiments(withResponse response: [[String: Any]]?) {
    // Cache fetched experiment payloads.
    experimentPayloads.removeAll()
    dbManager.deleteExperimentTable(forKey: ConfigConstants.experimentTableKeyPayload)

    if let response {
      for experiment in response {
        do {
          let jsonData = try JSONSerialization.data(withJSONObject: experiment)
          experimentPayloads.append(jsonData)
          dbManager
            .insertExperimentTable(
              withKey: ConfigConstants.experimentTableKeyPayload,
              value: jsonData
            )
        } catch {
          RCLog.error("I-RCN000030", "Invalid experiment payload to be serialized.")
        }
      }
    }
  }

  /// Update experiments to Firebase Analytics when `activateWithCompletion:` happens.
  @objc open func updateExperiments(handler: (((any Error)?) -> Void)? = nil) {
    let lifecycleEvent = LifecycleEvents()

    // Get the last experiment start time prior to the latest payload.
    let lastStartTime = experimentMetadata[Self.experimentMetadataKeyLastStartTime] as? Double

    // Update the last experiment start time with the latest payload.
    updateExperimentStartTime()
    experimentController?
      .updateExperiments(
        withServiceOrigin: Self.serviceOrigin,
        events: lifecycleEvent,
        policy: .discardOldest,
        lastStartTime: lastStartTime ?? 0,
        payloads: experimentPayloads,
        completionHandler: handler
      )

    // Update activated experiments payload and metadata in DB.
    updateActiveExperimentsInDB()
  }

  @objc private func updateExperimentStartTime() {
    let existingLastStartTime =
      experimentMetadata[Self.experimentMetadataKeyLastStartTime] as? Double

    let latestStartTime = latestStartTime(existingLastStartTime: existingLastStartTime ?? 0)

    experimentMetadata[Self.experimentMetadataKeyLastStartTime] = latestStartTime

    guard JSONSerialization.isValidJSONObject(experimentMetadata) else {
      RCLog.error("I-RCN000028", "Invalid fetched experiment metadata to be serialized.")
      return
    }

    if let serializedExperimentMetadata = try? JSONSerialization.data(
      withJSONObject: experimentMetadata,
      options: .prettyPrinted
    ) {
      dbManager
        .insertExperimentTable(
          withKey: ConfigConstants.experimentTableKeyMetadata,
          value: serializedExperimentMetadata
        )
    }
  }

  @objc private func updateActiveExperimentsInDB() {
    // Put current fetched experiment payloads into activated experiment DB.
    activeExperimentPayloads.removeAll()
    dbManager.deleteExperimentTable(forKey: ConfigConstants.experimentTableKeyActivePayload)
    for data in experimentPayloads {
      activeExperimentPayloads.append(data)
      dbManager
        .insertExperimentTable(
          withKey: ConfigConstants.experimentTableKeyActivePayload,
          value: data
        )
    }
  }

  private func latestStartTime(existingLastStartTime: Double) -> TimeInterval {
    experimentController?
      .latestExperimentStartTimestampBetweenTimestamp(
        existingLastStartTime,
        andPayloads: experimentPayloads
      ) ?? 0
  }
}
