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
package import InternalGoogleAIDataModels

/// Service tier options for model requests.
public enum ServiceTier: Codable, Sendable, Equatable, Hashable {
  case unspecified
  case standard
  case flex
  case priority
  case unrecognized(_ value: String)
}

// MARK: - GoogleAI Mappings

extension ServiceTier {
  package func toGoogleAI() -> GoogleAI.GenerateContentRequest.ServiceTier {
    switch self {
    case .unspecified: .unspecified
    case .standard: .standard
    case .flex: .flex
    case .priority: .priority
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI tier: GoogleAI.GenerateContentRequest.ServiceTier) {
    switch tier {
    case .unspecified: self = .unspecified
    case .standard: self = .standard
    case .flex: self = .flex
    case .priority: self = .priority
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }

  package func toGoogleAIUsageServiceTier() -> GoogleAI.UsageMetadata.ServiceTier {
    switch self {
    case .unspecified: .unspecified
    case .standard: .standard
    case .flex: .flex
    case .priority: .priority
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAIUsageServiceTier tier: GoogleAI.UsageMetadata.ServiceTier) {
    switch tier {
    case .unspecified: self = .unspecified
    case .standard: self = .standard
    case .flex: self = .flex
    case .priority: self = .priority
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}
