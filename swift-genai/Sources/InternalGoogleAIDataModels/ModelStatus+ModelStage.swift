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

extension GoogleAI.ModelStatus {
  /// The stage of the underlying model.
  public enum ModelStage: Codable, Sendable, Equatable, Hashable {
    /// The underlying model is subject to lots of tunings.
    @available(*, deprecated)
    case unstableExperimental
    
    /// Models in this stage are for experimental purposes only.
    case experimental
    
    /// Models in this stage are more mature than experimental models.
    case preview
    
    /// Models in this stage are considered stable and ready for production use.
    case stable
    
    /// If the model is on this stage, it means that this model is on the path to deprecation in near future. Only existing customers can use this model.
    case legacy
    
    /// Models in this stage are deprecated. These models cannot be used.
    @available(*, deprecated)
    case deprecated
    
    /// Models in this stage are retired. These models cannot be used.
    case retired
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GoogleAI.ModelStatus.ModelStage: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .unstableExperimental: "UNSTABLE_EXPERIMENTAL"
    case .experimental: "EXPERIMENTAL"
    case .preview: "PREVIEW"
    case .stable: "STABLE"
    case .legacy: "LEGACY"
    case .deprecated: "DEPRECATED"
    case .retired: "RETIRED"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "UNSTABLE_EXPERIMENTAL": self = .unstableExperimental
    case "EXPERIMENTAL": self = .experimental
    case "PREVIEW": self = .preview
    case "STABLE": self = .stable
    case "LEGACY": self = .legacy
    case "DEPRECATED": self = .deprecated
    case "RETIRED": self = .retired
    default: self = .unrecognized(rawValue)
    }
  }
}