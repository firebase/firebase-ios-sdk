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

import Combine
import Observation

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct QueryRequest: OperationRequest {
  public var operationName: String
  public var variables: (any Codable)?

  public init(operationName: String, variables: (any Codable)? = nil) {
    self.operationName = operationName
    self.variables = variables
  }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol QueryRef: OperationRef {

  // This call starts query execution and publishes data
  func subscribe() async throws -> AnyPublisher<Result<ResultDataType, DataConnectError>, Never>
}



@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public actor GenericQueryRef<ResultDataType: Codable>: QueryRef {

  private var resultsPublisher = PassthroughSubject<Result<ResultDataType, DataConnectError>, Never>()

  public var request: QueryRequest

  private var dataType: ResultDataType.Type

  private var grpcClient: GrpcClient

  init(request: QueryRequest, dataType: ResultDataType.Type, grpcClient: GrpcClient) {
    self.request = request
    self.dataType = dataType
    self.grpcClient = grpcClient
  }

  // This call starts query execution and publishes data to data var
  // In v0, it simply reloads query results
  public func subscribe() -> AnyPublisher<Result<ResultDataType, DataConnectError>, Never> {
    Task {
      do {
        _ = try await reloadResults()
      } catch {

      }
    }
    return resultsPublisher.eraseToAnyPublisher()
  }

  // one-shot execution. It will fetch latest data, update any caches
  // and updates the published data var
  public func execute() async throws -> OperationResult<ResultDataType> {
    let resultData = try await reloadResults()
    return OperationResult(data: resultData)
  }

  private func reloadResults() async throws -> ResultDataType {
    let results = try await grpcClient.executeQuery(
      request: request ,
      resultType: ResultDataType.self
    )
    await updateData(data: results.data)
    return results.data
  }

  func updateData(data: ResultDataType) async {
    self.resultsPublisher.send(.success(data))
  }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol ObservableQueryRef: OperationRef {
  var data: ResultDataType? {get}
  var lastError: DataConnectError? {get}
}

// QueryRef class used with ObservableObject protocol
// data: Published variable that contains bindable results of the query.
// lastError: Published variable that contains DataConnectError if last fetch had error.
//            If last fetch was successful, this variable is cleared
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public class QueryRefObservableObject<ResultDataType: Codable>: ObservableObject, ObservableQueryRef {

  private var request: OperationRequest

  private var baseRef: GenericQueryRef<ResultDataType>

  private var resultsCancellable: AnyCancellable?

  init(request: QueryRequest, dataType: ResultDataType.Type, grpcClient: GrpcClient) {
    self.request = request
    baseRef = GenericQueryRef(request: request, dataType: dataType, grpcClient: grpcClient)

    setupSubscription()
  }

  private func setupSubscription() {
    Task {
      resultsCancellable = await baseRef.subscribe()
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { result in
          switch result {
          case .success(let resultData):
            self.data = resultData
            self.lastError = nil
          case .failure(let dcerror):
            self.lastError = dcerror
          }
        })
    }
  }

  // contains published results of the query
  @Published private(set) public var data: ResultDataType?

  // last error received. if last fetch was successful, this is cleared
  @Published private(set) public var lastError: DataConnectError?

  public func execute() async throws -> OperationResult<ResultDataType> {
    let result = try await baseRef.execute()
    return result
  }
}


// QueryRef class compatible with the Observation framework introduced in iOS 17
// data: Published variable that contains bindable results of the query.
// lastError: Published variable that contains DataConnectError if last fetch had error.
//            If last fetch was successful, this variable is cleared
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
@Observable
public class QueryRefObservation<ResultDataType: Codable>: ObservableQueryRef {

  private var request: QueryRequest

  private var baseRef: GenericQueryRef<ResultDataType>

  private var resultsCancellable: AnyCancellable?

  init(request: QueryRequest, dataType: ResultDataType.Type, grpcClient: GrpcClient) {
    self.request = request
    baseRef = GenericQueryRef(request: request, dataType: dataType, grpcClient: grpcClient)
  }

  private func setupSubscription() {
    Task {
      resultsCancellable = await baseRef.subscribe()
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { result in
          switch result {
          case .success(let resultData):
            self.data = resultData
            self.lastError = nil
          case .failure(let dcerror):
            self.lastError = dcerror
          }
        })
    }
  }

  // contains published results of the query
  private(set) public var data: ResultDataType?

  // last error received. if last fetch was successful, this is cleared
  private(set) public var lastError: DataConnectError?

  public func execute() async throws -> OperationResult<ResultDataType> {
    let result = try await baseRef.execute()
    return result
  }


}
