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
public struct OperationResult<ResultDataType: Codable> {
  public var data: ResultDataType
}

// notional protocol that denotes a variable.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol OperationVariable: Encodable, Hashable, Equatable {}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol OperationRequest {
  associatedtype VariableType: OperationVariable
  var operationName: String { get } // Name within Connector definition
  var variables: VariableType? { get }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol OperationRef {
  associatedtype ResultDataType: Codable

  func execute() async throws -> OperationResult<ResultDataType>
}
