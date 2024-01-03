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


@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct QueryRequest: OperationRequest {

  public var operationName: String
  public var variables: (any Codable)?

  public init(operationName: String, variables: (any Codable)? = nil) {
    self.operationName = operationName
    self.variables = variables
  }
}

@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public class QueryRef<ResultDataType: Codable>: OperationRef, ObservableObject {

  internal var request: OperationRequest

  private var dataType: ResultDataType.Type

  // contains published results of the query
  @Published var data: ResultDataType?

  // last error received. if last fetch was successful, this is cleared
  @Published var lastError: DataConnectError?

  private var grpcClient: GrpcClient

  init(request: QueryRequest, dataType: ResultDataType.Type, grpcClient: GrpcClient) {
    self.request = request
    self.dataType = dataType
    self.grpcClient = grpcClient
  }

  //This call starts query execution and publishes data to data var
  //In v0, it simply reloads query results
  public func startObserving() async throws {
    try await reloadResults()
  }

  // one-shot execution. It will fetch latest data, update any caches
  // and updates the published data var
  public func execute() async throws -> OperationResult<ResultDataType> {
    try await reloadResults()
    return OperationResult(data: self.data!)
  }

  private func reloadResults() async throws {
    let results = try await grpcClient.executeQuery(request: request as! QueryRequest, resultType: ResultDataType.self)
    await updateData(data: results.data)
  }

  // method separated to set the data var out since we have to update Published vars on main thread
  @MainActor
  private func updateData(data: ResultDataType) {
    self.data = data
  }

}
