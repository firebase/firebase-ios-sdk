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


  // MARK: Static Creation

  public class func dataConnect(app: FirebaseApp? = FirebaseApp.app(), connectorConfig: ConnectorConfig, settings: DataConnectSettings = DataConnectSettings()) -> DataConnect {

    guard let app = app else {
      fatalError("No Firebase App present")
    }

    return DataConnect(connectorConfig: connectorConfig, app: app, settings: settings)
  }

  // MARK: Emulator

  public func useEmulator(host: String = "localhost",
                          port: Int = 9510) {
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
        auth: Auth.auth(app: self.app))

      operationsManager = OperationsManager(grpcClient: grpcClient)
  }

  // MARK: Init

  init(connectorConfig: ConnectorConfig, app: FirebaseApp,  settings: DataConnectSettings) {
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

  public func query<ResultDataType: Codable, Variable: OperationVariable>(request: QueryRequest<Variable>,
                                                   resultsDataType: ResultDataType
    .Type, publisher: ResultsPublisherType = .observableObject) -> any ObservableQueryRef {
    return operationsManager.queryRef(for: request, with: resultsDataType, publisher: publisher)
  }

  public func mutation<ResultDataType: Codable, VariableType: OperationVariable>(request: MutationRequest<VariableType>,
                                                      resultsDataType: ResultDataType
                                                        .Type) -> MutationRef<ResultDataType, VariableType> {
    return operationsManager.mutationRef(for: request, with: resultsDataType)
  }
}
