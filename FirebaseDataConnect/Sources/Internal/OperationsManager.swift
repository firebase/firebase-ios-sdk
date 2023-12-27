//
//  File.swift
//  
//
//  Created by Aashish Patil on 12/18/23.
//

import Foundation

@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
class OperationsManager {

  private var grpcClient: GrpcClient

  init(grpcClient: GrpcClient) {
    self.grpcClient = grpcClient
  }

  func queryRef<ResultDataType: Codable>(for request: QueryRequest, with resultType: ResultDataType.Type) -> QueryRef<ResultDataType> {
    //returning for now
    return QueryRef(request: request, dataType: resultType, grpcClient: grpcClient)
  }

  func mutationRef<ResultDataType: Codable>(for request: MutationRequest, with resultType: ResultDataType.Type) -> MutationRef<ResultDataType> {
    return MutationRef(request: request, dataType: resultType, grpcClient: grpcClient)
  }

}
