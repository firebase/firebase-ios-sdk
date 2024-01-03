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
class GrpcClient {
  private var projectId: String

  private let threadPoolSize = 1

  private var serverSettings: ServerSettings

  private var serviceConfig: ServiceConfig

  // projects/{project}/locations/{location}/services/{service}/operationSets/{operation_set}/revisions/{revision}
  private var connectorName: String = "" // Operation Set Full Qualified Name

  private lazy var client: Google_Firebase_Dataconnect_V1main_DataServiceAsyncClient? = {
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
      return Google_Firebase_Dataconnect_V1main_DataServiceAsyncClient(channel: channel)

    } catch {
      // TODO: Convert to using logger
      print("Error initing GRPC client \(error)")
      return nil
    }
  }()

  init(projectId: String, serverSettings: ServerSettings, serviceConfig: ServiceConfig) {
    self.projectId = projectId
    self.serverSettings = serverSettings
    self.serviceConfig = serviceConfig

    createConnectorName()
  }

  private func createConnectorName() {
    connectorName =
      "projects/\(projectId)/locations/\(serviceConfig.location.rawValue)/services/\(serviceConfig.serviceId)/operationSets/\(serviceConfig.connector)/revisions/r"
  }

  func executeQuery<ResultType: Codable>(request: QueryRequest,
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

  func executeMutation<ResultType: Codable>(request: MutationRequest,
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
