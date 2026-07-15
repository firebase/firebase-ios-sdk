// Copyright 2026 Google LLC
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

extension GeminiDataModels.UsageMetadata {
  /// Output only. The traffic type for this request.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This property is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Output only. The traffic type for this request.
  package enum TrafficType: Codable, Sendable, Equatable, Hashable {
    /// The request was processed using Pay-As-You-Go quota.
    case onDemand
    
    /// Type for Priority Pay-As-You-Go traffic.
    case onDemandPriority
    
    /// Type for Flex traffic.
    case onDemandFlex
    
    /// Type for Provisioned Throughput traffic.
    case provisionedThroughput
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GeminiDataModels.UsageMetadata.TrafficType: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .onDemand: "ON_DEMAND"
    case .onDemandPriority: "ON_DEMAND_PRIORITY"
    case .onDemandFlex: "ON_DEMAND_FLEX"
    case .provisionedThroughput: "PROVISIONED_THROUGHPUT"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "ON_DEMAND": self = .onDemand
    case "ON_DEMAND_PRIORITY": self = .onDemandPriority
    case "ON_DEMAND_FLEX": self = .onDemandFlex
    case "PROVISIONED_THROUGHPUT": self = .provisionedThroughput
    default: self = .unrecognized(rawValue)
    }
  }
}