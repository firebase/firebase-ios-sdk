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


@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
class OperationsManager {
  private var grpcClient: GrpcClient

  init(grpcClient: GrpcClient) {
    self.grpcClient = grpcClient
  }

  func queryRef<ResultDataType: Codable, VariableType: OperationVariable>(for request: QueryRequest<VariableType>,
                                                                          with resultType: ResultDataType
    .Type, publisher: ResultsPublisherType = .auto) -> any ObservableQueryRef {

      switch publisher {
      case .auto, .observation:
        if #available(iOS 17, *) {
          return QueryRefObservation<ResultDataType, VariableType>(request: request, dataType: resultType, grpcClient: self.grpcClient) as! (any ObservableQueryRef)
        } else {
          return QueryRefObservableObject<ResultDataType, VariableType>(request: request, dataType: resultType, grpcClient: self.grpcClient) as! (any ObservableQueryRef)
        }
      case .observableObject:
        return QueryRefObservableObject<ResultDataType, VariableType>(request: request, dataType: resultType, grpcClient: self.grpcClient) as! (any ObservableQueryRef)
      }
    }

  func mutationRef<ResultDataType: Codable, VariableType: OperationVariable>(for request: MutationRequest<VariableType>,
                                          with resultType: ResultDataType
  .Type) -> MutationRef<ResultDataType, VariableType> {
    return MutationRef(request: request, grpcClient: grpcClient)
  }
}


