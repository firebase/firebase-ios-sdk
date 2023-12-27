//
//  File.swift
//  
//
//  Created by Aashish Patil on 12/26/23.
//

import Foundation

@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct MutationRequest: OperationRequest {

  public var operationName: String
  public var variables: (any Codable)?

  public init(operationName: String, variables: (any Codable)? = nil) {
    self.operationName = operationName
    self.variables = variables
  }
}

@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public class MutationRef<ResultDataType: Codable>: OperationRef {

  var request: any OperationRequest

  var dataType: ResultDataType.Type

  private var grpcClient: GrpcClient

  init(request: any OperationRequest, dataType: ResultDataType.Type, grpcClient: GrpcClient) {
    self.request = request
    self.dataType = dataType
    self.grpcClient = grpcClient
  }

  public func execute() async throws -> OperationResult<ResultDataType> {
    let results = try await grpcClient.executeMutation(request: request as! MutationRequest, resultType: ResultDataType.self)
    return results
  }

}
