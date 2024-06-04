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

import FirebaseAuth
import FirebaseCore

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public class DataConnect {
  private var connectorConfig: ConnectorConfig
  private var app: FirebaseApp
  private var settings: DataConnectSettings

  private var grpcClient: GrpcClient
  private var operationsManager: OperationsManager

  private static var instanceStore = InstanceStore()

  // MARK: Static Creation

  public class func dataConnect(app: FirebaseApp? = FirebaseApp.app(),
                                connectorConfig: ConnectorConfig,
                                settings: DataConnectSettings = DataConnectSettings())
    -> DataConnect {
    guard let app = app else {
      fatalError("No Firebase App present")
    }

    return instanceStore.instance(for: app, config: connectorConfig, settings: settings)
  }

  // MARK: Emulator

  public func useEmulator(host: String = "127.0.0.1",
                          port: Int = 9399) {
    settings = DataConnectSettings(host: host, port: port, sslEnabled: false)

    // TODO: - shutdown grpc client
    // self.grpcClient.close
    // self.operations.close

    guard let projectID = app.options.projectID else {
      fatalError("Firebase DataConnect requires the projectID to be set in the app options")
    }

    grpcClient = GrpcClient(
      projectId: projectID,
      settings: settings,
      connectorConfig: connectorConfig,
      auth: Auth.auth(app: app)
    )

    operationsManager = OperationsManager(grpcClient: grpcClient)
  }

  // MARK: Init

  init(app: FirebaseApp, connectorConfig: ConnectorConfig, settings: DataConnectSettings) {
    self.app = app
    self.settings = settings
    self.connectorConfig = connectorConfig

    guard let projectID = app.options.projectID else {
      fatalError("Firebase DataConnect requires the projectID to be set in the app options")
    }

    grpcClient = GrpcClient(
      projectId: projectID,
      settings: settings,
      connectorConfig: connectorConfig,
      auth: Auth.auth(app: app)
    )
    operationsManager = OperationsManager(grpcClient: grpcClient)
  }

  // MARK: Operations

  public func query<ResultDataType: Codable,
    Variable: OperationVariable>(request: QueryRequest<Variable>,
                                 resultsDataType: ResultDataType
                                   .Type,
                                 publisher: ResultsPublisherType = .observableObject)
    -> any ObservableQueryRef {
    return operationsManager.queryRef(for: request, with: resultsDataType, publisher: publisher)
  }

  public func mutation<ResultDataType: Codable,
    VariableType: OperationVariable>(request: MutationRequest<VariableType>,
                                     resultsDataType: ResultDataType
                                       .Type)
    -> MutationRef<ResultDataType,
      VariableType> {
    return operationsManager.mutationRef(for: request, with: resultsDataType)
  }
}

// MARK: Instance Creation

// Support for creating or reusing DataConnect instances.
// Instances are keyed by ConnectorConfig and FirebaseApp (projectID)
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
private struct InstanceKey: Hashable, Equatable {
  let config: ConnectorConfig
  let app: FirebaseApp

  init(app: FirebaseApp, config: ConnectorConfig) {
    self.app = app
    self.config = config
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(app.name)
    hasher.combine(app.options.projectID)
    hasher.combine(config)
  }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
private class InstanceStore {
  let accessQ = DispatchQueue(
    label: "firebase.dataconnect.instanceQ",
    autoreleaseFrequency: .workItem
  )

  var instances = [InstanceKey: DataConnect]()

  func instance(for app: FirebaseApp, config: ConnectorConfig,
                settings: DataConnectSettings) -> DataConnect {
    accessQ.sync {
      let key = InstanceKey(app: app, config: config)
      if let inst = instances[key] {
        return inst
      } else {
        let dc = DataConnect(app: app, connectorConfig: config, settings: settings)
        instances[key] = dc
        return dc
      }
    }
  }
}
