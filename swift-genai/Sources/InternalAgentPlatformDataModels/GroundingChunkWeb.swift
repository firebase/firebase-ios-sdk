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


extension AgentPlatform {
  /// A `Web` chunk is a piece of evidence that comes from a web page. It contains the URI of the web page, the title of the page, and the domain of the page. This is used to provide the user with a link to the source of the information.
  public struct GroundingChunkWeb: Codable, Sendable, Equatable, Hashable {
    /// The domain of the web page that contains the evidence. This can be used to filter out low-quality sources.
    public var domain: String?
    
    /// The title of the web page that contains the evidence.
    public var title: String?
    
    /// The URI of the web page that contains the evidence.
    public var uri: String?
    
    /// Creates a new `GroundingChunkWeb`.
    public init(
      domain: String? = nil,
      title: String? = nil,
      uri: String? = nil
    ) {
      self.domain = domain
      self.title = title
      self.uri = uri
    }
    enum CodingKeys: String, CodingKey {
      case domain = "domain"
      case title = "title"
      case uri = "uri"
    }
  }
}