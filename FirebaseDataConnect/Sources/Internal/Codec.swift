//
//  File.swift
//  
//
//  Created by Aashish Patil on 12/18/23.
//

import Foundation


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

  func createInternalQuery(connectorName:String, request: QueryRequest) throws -> Google_Firebase_Dataconnect_V1main_ExecuteQueryRequest {
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

  func createInternalMutation(connectorName: String, request: MutationRequest) throws -> Google_Firebase_Dataconnect_V1main_ExecuteMutationRequest {
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
