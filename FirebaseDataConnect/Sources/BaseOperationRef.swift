//
//  File.swift
//  
//
//  Created by Aashish Patil on 12/7/23.
//

import Foundation

@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct OperationResult<ResultDataType: Codable> {
  public var data: ResultDataType
}

@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol OperationRequest {
  var operationName: String { get } //Name within Connector definition
  var variables: (any Codable)? { get set }
}

@available (macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
protocol OperationRef {

  associatedtype ResultDataType: Codable

  var request: any OperationRequest { get }

  func execute() async throws -> OperationResult<ResultDataType>
}
