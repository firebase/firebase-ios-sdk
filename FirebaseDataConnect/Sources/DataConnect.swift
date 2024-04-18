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

import FirebaseCore

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public class DataConnect {
  private var app: FirebaseApp
  fileprivate var settings: DataConnectSettings = .defaults
  private var connectorConfig: ConnectorConfig

  private var emulatorSettings: DataConnectSettings?

  private var grpcClient: GrpcClient
  private var operationsManager: OperationsManager

  // MARK: Init

  public class func dataConnect(app: FirebaseApp, connectorConfig: ConnectorConfig, settings: DataConnectSettings) -> DataConnect {
    let dataConnect = DataConnect(
      app: app,
      connectorConfig: connectorConfig,
      settings: settings
    )
    return dataConnect
  }

  public class func dataConnect(settings: DataConnectSettings,
                                connectorConfig: ConnectorConfig) throws -> DataConnect {
    guard let app = FirebaseApp.app() else {
      throw DataConnectError.appNotConfigured
    }

    return DataConnect(app: app, connectorConfig: connectorConfig, settings: settings)
  }

  public class func dataConnect(connectorConfig: ConnectorConfig) -> DataConnect {
    guard let app = FirebaseApp.app() else {
      fatalError("No default Firebase App present")
    }

    return DataConnect(
      app: app,
      connectorConfig: connectorConfig,
      settings: DataConnectSettings.defaults
    )
  }

  public class func dataConnect(app: FirebaseApp, connectorConfig: ConnectorConfig) -> DataConnect {
    return DataConnect(
      app: app,
      connectorConfig: connectorConfig,
      settings: DataConnectSettings.defaults
    )
  }

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
      connectorConfig: connectorConfig
    )
    operationsManager = OperationsManager(grpcClient: grpcClient)
  }

  public func useEmulator(host: String = "localhost",
                          port: Int = 9400) {
    emulatorSettings = DataConnectSettings(hostName: host, port: port, sslEnabled: false)

    // TODO: - shutdown grpc client
    // self.grpcClient.close
    // self.operations.close

    guard let projectID = app.options.projectID else {
      fatalError("Firebase DataConnect requires the projectID to be set in the app options")
    }

    grpcClient = GrpcClient(
      projectId: projectID,
      settings: emulatorSettings!,
      connectorConfig: connectorConfig
    )
    operationsManager = OperationsManager(grpcClient: grpcClient)
  }

  // MARK: Operations

  public func getQueryRef<ResultDataType: Codable, Variable: OperationVariable>(request: QueryRequest<Variable>,
                                                   resultsDataType: ResultDataType
    .Type, publisher: ResultsPublisherType = .observableObject) -> any ObservableQueryRef {
    return operationsManager.queryRef(for: request, with: resultsDataType, publisher: publisher)
  }

  public func getMutationRef<ResultDataType: Codable, VariableType: OperationVariable>(request: MutationRequest<VariableType>,
                                                      resultsDataType: ResultDataType
                                                        .Type) -> MutationRef<ResultDataType, VariableType> {
    return operationsManager.mutationRef(for: request, with: resultsDataType)
  }
}
