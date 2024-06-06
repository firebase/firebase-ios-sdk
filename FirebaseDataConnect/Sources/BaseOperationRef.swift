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
public struct OperationResult<ResultData: Decodable> {
  public var data: ResultData
}

// notional protocol that denotes a variable.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol OperationVariable: Encodable, Hashable, Equatable {}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol OperationRequest {
  associatedtype Variable: OperationVariable
  var operationName: String { get } // Name within Connector definition
  var variables: Variable? { get }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol OperationRef {
  associatedtype ResultData: Decodable

  func execute() async throws -> OperationResult<ResultData>
}
