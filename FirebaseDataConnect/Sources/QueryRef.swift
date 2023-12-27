//
//  File.swift
//  
//
//  Created by Aashish Patil on 12/7/23.
//

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

  var request: OperationRequest

  var dataType: ResultDataType.Type

  @Published var data: ResultDataType?

  private var grpcClient: GrpcClient

  init(request: QueryRequest, dataType: ResultDataType.Type, grpcClient: GrpcClient) {
    self.request = request
    self.dataType = dataType
    self.grpcClient = grpcClient
  }

  public func execute() async throws -> OperationResult<ResultDataType> {
    let results = try await grpcClient.executeQuery(request: request as! QueryRequest, resultType: ResultDataType.self)
    return results
  }

  func reload() async throws {
    let results = try await grpcClient.executeQuery(request: request as! QueryRequest, resultType: ResultDataType.self)
    self.data = results.data
  }

}
