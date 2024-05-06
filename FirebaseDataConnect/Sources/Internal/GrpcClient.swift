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
import NIOHPACK
import NIOPosix
import SwiftProtobuf
import FirebaseCoreInternal
import FirebaseAuth


@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
actor GrpcClient {
  private let projectId: String

  private let threadPoolSize = 1

  private let serverSettings: DataConnectSettings

  private let connectorConfig: ConnectorConfig

  private let connectorName: String // Fully qualified connector name

  private let auth: Auth

  private enum RequestHeaders {
    static let googRequestParamsHeader = "x-goog-request-params"
    static let authorizationHeader = "x-firebase-auth-token"
  }

  private let googRequestHeaderValue: String

  private lazy var client: Google_Firebase_Dataconnect_V1alpha_ConnectorServiceAsyncClient? = {
    do {
      let group = PlatformSupport.makeEventLoopGroup(loopCount: threadPoolSize)
      let channel = try GRPCChannelPool.with(
        target: .host(serverSettings.host, port: serverSettings.port),
        transportSecurity: serverSettings
          .sslEnabled ? .tls(GRPCTLSConfiguration.makeClientDefault(compatibleWith: group)) :
          .plaintext,
        eventLoopGroup: group
      )
      print("Created Channel \(channel) for host \(serverSettings.host) port \(serverSettings.port) ssl \(serverSettings.sslEnabled)")
      return Google_Firebase_Dataconnect_V1alpha_ConnectorServiceAsyncClient(channel: channel)

    } catch {
      // TODO: Convert to using logger
      print("Error initing GRPC client \(error)")
      return nil
    }
  }()

  init(projectId: String, settings: DataConnectSettings, connectorConfig: ConnectorConfig, auth: Auth) {
    self.projectId = projectId
    self.serverSettings = settings
    self.connectorConfig = connectorConfig
    self.auth = auth

    self.connectorName =
      "projects/\(projectId)/locations/\(connectorConfig.location.rawValue)/services/\(connectorConfig.serviceId)/connectors/\(connectorConfig.connector)"

    self.googRequestHeaderValue = "location=\(self.connectorConfig.location.rawValue)&frontend=data"
  }

  func executeQuery<ResultType: Codable, VariableType: OperationVariable>(request: QueryRequest<VariableType>,
                                         resultType: ResultType.Type)
  async throws -> OperationResult<ResultType> {
    guard let client else {
      throw DataConnectError.grpcNotConfigured
    }

    let codec = Codec()
    let grpcRequest = try codec.createQueryRequestProto(
      connectorName: connectorName,
      request: request
    )

    do {
      print("calling execute query in grpcClient")
      let results = try await client.executeQuery(grpcRequest,callOptions: createCallOptions())
      print("done calling executeQuery")

      // Not doing error decoding here
      if let decodedResults = try codec.decode(result: results.data, asType: resultType) {
        return OperationResult(data: decodedResults)
      } else {
        // In future, set this as error in OperationResult
        throw DataConnectError.decodeFailed
      }
    } catch {
      print("Error executing query \(error)")
      throw error
    }
  }

  func executeMutation<ResultType: Codable, VariableType: OperationVariable>(request: MutationRequest<VariableType>,
                                                                             resultType: ResultType.Type)
  async throws -> OperationResult<ResultType> {
    guard let client else {
      throw DataConnectError.grpcNotConfigured
    }

    let codec = Codec()
    let grpcRequest = try codec.createMutationRequestProto(
      connectorName: connectorName,
      request: request
    )

    do {
      let results = try await client.executeMutation(grpcRequest, callOptions: createCallOptions())
      print("executed mutation \(results)")
      if let decodedResults = try codec.decode(result: results.data, asType: resultType) {
        return OperationResult(data: decodedResults)
      } else {
        throw DataConnectError.decodeFailed
      }
    } catch {
      print("Error executing mutation \(error)")
      throw error
    }
  }

  private func createCallOptions() async -> CallOptions {
    var headers = HPACKHeaders()

    headers.add(name: RequestHeaders.googRequestParamsHeader, value: self.googRequestHeaderValue)

    // add token if available
    do {
      if let token = try await auth.currentUser?.getIDToken() {
        headers.add(name: RequestHeaders.authorizationHeader, value: "\(token)")
        print("added token \(token)")
        
      } else {
        print("No auth token available. Not adding auth header")
      }
    } catch {
      print("Error getting auth token. Not adding it. \(error)")
    }

    let options = CallOptions(customMetadata: headers)
    return options
  }
}
