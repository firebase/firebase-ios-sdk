// Copyright 2025 Google LLC
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

/// Configuration options for live content generation.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
struct BidiGenerationConfig: Encodable, Sendable {
  let temperature: Float?
  let topP: Float?
  let topK: Int?
  let candidateCount: Int?
  let maxOutputTokens: Int?
  let presencePenalty: Float?
  let frequencyPenalty: Float?
  let responseModalities: [ResponseModality]?
  let speechConfig: BidiSpeechConfig?

  init(temperature: Float? = nil, topP: Float? = nil, topK: Int? = nil,
       candidateCount: Int? = nil, maxOutputTokens: Int? = nil,
       presencePenalty: Float? = nil, frequencyPenalty: Float? = nil,
       responseModalities: [ResponseModality]? = nil,
       speechConfig: BidiSpeechConfig? = nil) {
    self.temperature = temperature
    self.topP = topP
    self.topK = topK
    self.candidateCount = candidateCount
    self.maxOutputTokens = maxOutputTokens
    self.presencePenalty = presencePenalty
    self.frequencyPenalty = frequencyPenalty
    self.responseModalities = responseModalities
    self.speechConfig = speechConfig
  }
}
