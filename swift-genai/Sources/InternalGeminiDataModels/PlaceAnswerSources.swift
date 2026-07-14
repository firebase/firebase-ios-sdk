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


extension GeminiDataModels {
  /// Collection of sources that provide answers about the features of a given place in Google Maps. Each PlaceAnswerSources message corresponds to a specific place in Google Maps. The Google Maps tool used these sources in order to answer questions about features of the place (e.g: "does Bar Foo have Wifi" or "is Foo Bar wheelchair accessible?"). Currently we only support review snippets as sources.
  /// 
  /// Variant:
  /// The sources that were used to generate the place answer. This includes review snippets and photos that were used to generate the answer, as well as URIs to flag content.
  package struct PlaceAnswerSources: Codable, Sendable, Equatable, Hashable {
    /// Snippets of reviews that are used to generate answers about the features of a given place in Google Maps.
    /// 
    /// Variant:
    /// Snippets of reviews that were used to generate the answer.
    package let reviewSnippets: [ReviewSnippet]?
    
    /// Creates a new `PlaceAnswerSources`.
    package init(
      reviewSnippets: [ReviewSnippet]? = nil
    ) {
      self.reviewSnippets = reviewSnippets
    }
    enum CodingKeys: String, CodingKey {
      case reviewSnippets = "reviewSnippets"
    }
  }
}