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

import FirebaseAppCheck
import FirebaseAuth
import FirebaseCoreInternal
import FirebaseSharedSwift
import GRPC
import NIOCore
import NIOHPACK
import NIOPosix
import OSLog
import SwiftProtobuf

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
actor GrpcClient: CustomStringConvertible {
  nonisolated let description: String

  private let projectId: String

  private let threadPoolSize = 1

  private let serverSettings: DataConnectSettings

  private let connectorConfig: ConnectorConfig

  private let connectorName: String // Fully qualified connector name

  private let auth: Auth

  private let appCheckEnabled = false

  private let appCheck: AppCheck?

  private enum RequestHeaders {
    static let googRequestParamsHeader = "x-goog-request-params"
    static let authorizationHeader = "x-firebase-auth-token"
    static let appCheckHeader = "X-Firebase-AppCheck"
  }

  private let googRequestHeaderValue: String

  private lazy var client: Google_Firebase_Dataconnect_V1alpha_ConnectorServiceAsyncClient? = {
    do {
      FirebaseLogger.dataConnect.debug("\(self.description) initialization starts.")
      let group = PlatformSupport.makeEventLoopGroup(loopCount: threadPoolSize)
      let channel = try GRPCChannelPool.with(
        target: .host(serverSettings.host, port: serverSettings.port),
        transportSecurity: serverSettings
          .sslEnabled ? .tls(GRPCTLSConfiguration.makeClientDefault(compatibleWith: group)) :
          .plaintext,
        eventLoopGroup: group
      )
      FirebaseLogger.dataConnect.debug("\(self.description) has been created.")
      return Google_Firebase_Dataconnect_V1alpha_ConnectorServiceAsyncClient(channel: channel)
    } catch {
      FirebaseLogger.dataConnect.error("Error:\(error) when creating \(self.description).")
      return nil
    }
  }()

  init(projectId: String, settings: DataConnectSettings, connectorConfig: ConnectorConfig,
       auth: Auth,
       appCheck: AppCheck?) {
    self.projectId = projectId
    serverSettings = settings
    self.connectorConfig = connectorConfig
    self.auth = auth
    self.appCheck = appCheck

    connectorName =
      "projects/\(projectId)/locations/\(connectorConfig.location)/services/\(connectorConfig.serviceId)/connectors/\(connectorConfig.connector)"

    googRequestHeaderValue = "location=\(self.connectorConfig.location)&frontend=data"

    description = """
        GrpcClient: \
        projectId=\(projectId) \
        connector=\(connectorConfig.connector) \
        host=\(serverSettings.host) \
        port=\(serverSettings.port) \
        ssl=\(serverSettings.sslEnabled)
    """
  }

  func executeQuery<ResultType: Decodable,
    VariableType: OperationVariable>(request: QueryRequest<VariableType>,
                                     resultType: ResultType
                                       .Type)
    async throws -> OperationResult<ResultType> {
    guard let client else {
      FirebaseLogger.dataConnect
        .error("When calling executeQuery(), grpc client has not been configured.")
      throw DataConnectError.grpcNotConfigured
    }

    let codec = Codec()
    let grpcRequest = try codec.createQueryRequestProto(
      connectorName: connectorName,
      request: request
    )

    do {
      try FirebaseLogger.dataConnect
        .debug("executeQuery() sends grpc request: \(grpcRequest.jsonString()).")
      let results = try await client.executeQuery(grpcRequest, callOptions: createCallOptions())
      try FirebaseLogger.dataConnect
        .debug("executeQuery() receives response: \(results.jsonString()).")
      // Not doing error decoding here
      if let decodedResults = try codec.decode(result: results.data, asType: resultType) {
        return OperationResult(data: decodedResults)
      } else {
        // In future, set this as error in OperationResult
        try FirebaseLogger.dataConnect
          .error("executeQuery() response: \(results.jsonString()) decode failed.")
        throw DataConnectError.decodeFailed
      }
    } catch {
      try FirebaseLogger.dataConnect
        .error(
          "executeQuery() with request: \(grpcRequest.jsonString()) grpc call FAILED with \(error)."
        )
      throw error
    }
  }

  func executeMutation<ResultType: Decodable,
    VariableType: OperationVariable>(request: MutationRequest<VariableType>,
                                     resultType: ResultType
                                       .Type)
    async throws -> OperationResult<ResultType> {
    guard let client else {
      FirebaseLogger.dataConnect
        .error("When calling executeMutation(), grpc client has not been configured.")
      throw DataConnectError.grpcNotConfigured
    }

    let codec = Codec()
    let grpcRequest = try codec.createMutationRequestProto(
      connectorName: connectorName,
      request: request
    )

    do {
      try FirebaseLogger.dataConnect
        .debug("executeMutation() sends grpc request: \(grpcRequest.jsonString()).")
      let results = try await client.executeMutation(grpcRequest, callOptions: createCallOptions())
      try FirebaseLogger.dataConnect
        .debug("executeMutation() receives response: \(results.jsonString()).")
      if let decodedResults = try codec.decode(result: results.data, asType: resultType) {
        return OperationResult(data: decodedResults)
      } else {
        try FirebaseLogger.dataConnect
          .error("executeMutation() response: \(results.jsonString()) decode failed.")
        throw DataConnectError.decodeFailed
      }
    } catch {
      try FirebaseLogger.dataConnect
        .error(
          "executeMutation() with request: \(grpcRequest.jsonString()) grpc call FAILED with \(error)."
        )
      throw error
    }
  }

  private func createCallOptions() async -> CallOptions {
    var headers = HPACKHeaders()

    headers.add(name: RequestHeaders.googRequestParamsHeader, value: googRequestHeaderValue)

    // Add Auth token if available
    do {
      if let token = try await auth.currentUser?.getIDToken() {
        headers.add(name: RequestHeaders.authorizationHeader, value: "\(token)")
        print("added Auth token \(token)")

      } else {
        FirebaseLogger.dataConnect.debug("No auth token available. Not adding auth header.")
      }
    } catch {
      FirebaseLogger.dataConnect
        .debug("Cannot get auth token successfully due to: \(error). Not adding auth header.")
    }

    // Add AppCheck token if available
    if appCheckEnabled {
      do {
        if let token = try await appCheck?.token(forcingRefresh: false) {
          headers.add(name: RequestHeaders.appCheckHeader, value: "\(token)")
          FirebaseLogger.dataConnect
            .debug("App Check token added: \(token)")
        } else {
          FirebaseLogger.dataConnect
            .debug("App Check token unavailable. Not adding App Check header.")
        }
      } catch {
        FirebaseLogger.dataConnect
          .debug(
            "Cannot get App Check token successfully due to: \(error). Not adding App Check header."
          )
      }
    }

    let options = CallOptions(customMetadata: headers)
    return options
  }
}
