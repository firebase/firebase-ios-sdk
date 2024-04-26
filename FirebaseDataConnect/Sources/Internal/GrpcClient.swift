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

import GRPC
import NIOCore
import NIOPosix
import SwiftProtobuf

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
actor GrpcClient {
  private let projectId: String

  private let threadPoolSize = 1

  private let serverSettings: DataConnectSettings

  private let connectorConfig: ConnectorConfig

  // projects/{project}/locations/{location}/services/{service}/operationSets/{operation_set}/revisions/{revision}
  private let connectorName: String // Operation Set Full Qualified Name

  private lazy var client: Google_Firebase_Dataconnect_V1alpha_ConnectorServiceAsyncClient? = {
    do {
      let group = PlatformSupport.makeEventLoopGroup(loopCount: threadPoolSize)
      let channel = try GRPCChannelPool.with(
        target: .host(serverSettings.hostName, port: serverSettings.port),
        transportSecurity: serverSettings
          .sslEnabled ? .tls(GRPCTLSConfiguration.makeClientDefault(compatibleWith: group)) :
          .plaintext,
        eventLoopGroup: group
      )
      print("Created Channel \(channel)")
      return Google_Firebase_Dataconnect_V1alpha_ConnectorServiceAsyncClient(channel: channel)

    } catch {
      // TODO: Convert to using logger
      print("Error initing GRPC client \(error)")
      return nil
    }
  }()

  init(projectId: String, settings: DataConnectSettings, connectorConfig: ConnectorConfig) {
    self.projectId = projectId
    self.serverSettings = settings
    self.connectorConfig = connectorConfig

    self.connectorName =
      "projects/\(projectId)/locations/\(connectorConfig.location.rawValue)/services/\(connectorConfig.serviceId)/operationSets/\(connectorConfig.connector)/revisions/r"
  }

  func executeQuery<ResultType: Codable, VariableType: OperationVariable>(request: QueryRequest<VariableType>,
                                         resultType: ResultType
                                           .Type) async throws -> OperationResult<ResultType> {
    guard let client else {
      throw DataConnectError.grpcNotConfigured
    }

    let codec = Codec()
    let grpcRequest = try codec.createQueryRequestProto(
      connectorName: connectorName,
      request: request
    )

    print("calling execute query in grpcClient")
    let results = try await client.executeQuery(grpcRequest)
    print("done calling executeQuery")

    // Not doing error decoding here
    if let decodedResults = try codec.decode(result: results.data, asType: resultType) {
      return OperationResult(data: decodedResults)
    } else {
      // In future, set this as error in OperationResult
      throw DataConnectError.decodeFailed
    }
  }

  func executeMutation<ResultType: Codable, VariableType: OperationVariable>(request: MutationRequest<VariableType>,
                                            resultType: ResultType
                                              .Type) async throws -> OperationResult<ResultType> {
    guard let client else {
      throw DataConnectError.grpcNotConfigured
    }

    let codec = Codec()
    let grpcRequest = try codec.createMutationRequestProto(
      connectorName: connectorName,
      request: request
    )

    let results = try await client.executeMutation(grpcRequest)

    if let decodedResults = try codec.decode(result: results.data, asType: resultType) {
      return OperationResult(data: decodedResults)
    } else {
      throw DataConnectError.decodeFailed
    }
  }
}
