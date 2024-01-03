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

import SwiftProtobuf

@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
class Codec {

  // Encode Codable to Protos
  func encode(args: any Codable) throws -> Google_Protobuf_Struct  {
    do {
      let jsonEncoder = JSONEncoder()
      let jsonData = try jsonEncoder.encode(args)
      let argsStruct = try Google_Protobuf_Struct(jsonUTF8Data: jsonData)
      return argsStruct
    }
  }

  // Decode Protos to Codable
  func decode<T: Codable>(result: Google_Protobuf_Struct, asType: T.Type) throws -> T? {
    do {
      let jsonData = try result.jsonUTF8Data()
      let jsonDecoder = JSONDecoder()

      let resultAsType = try jsonDecoder.decode(asType, from: jsonData)

      print("result as Type \(resultAsType)")

      return resultAsType
    }
  }

  func createQueryRequestProto(connectorName:String, request: QueryRequest) throws -> Google_Firebase_Dataconnect_V1main_ExecuteQueryRequest {
    do {
      var varStruct: Google_Protobuf_Struct? = nil
      if let variables = request.variables {
        varStruct = try encode(args: variables)
      }

      let internalRequest = Google_Firebase_Dataconnect_V1main_ExecuteQueryRequest.with { ireq in
        ireq.operationName = request.operationName

        if let varStruct {
          ireq.variables = varStruct
        } else {
          ireq.variables = Google_Protobuf_Struct()
        }

        ireq.name = connectorName
      }

      return internalRequest
    }
  }

  func createMutationRequestProto(connectorName: String, request: MutationRequest) throws -> Google_Firebase_Dataconnect_V1main_ExecuteMutationRequest {
    do {
      var varStruct: Google_Protobuf_Struct? = nil
      if let variables = request.variables {
        varStruct = try encode(args: variables)
      }

      let internalRequest = Google_Firebase_Dataconnect_V1main_ExecuteMutationRequest.with { ireq in
        ireq.operationName = request.operationName

        if let varStruct {
          ireq.variables = varStruct
        } else {
          // always provide an empty struct otherwise request fails.
          ireq.variables = Google_Protobuf_Struct()
        }

        ireq.name = connectorName
      }

      return internalRequest
    }
  }

}
