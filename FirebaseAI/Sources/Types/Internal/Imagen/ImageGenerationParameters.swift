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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct ImageGenerationParameters {
  let sampleCount: Int?
  let storageURI: String?
  let negativePrompt: String?
  let aspectRatio: String?
  let safetyFilterLevel: String?
  let personGeneration: String?
  let outputOptions: ImageGenerationOutputOptions?
  let addWatermark: Bool?
  let includeResponsibleAIFilterReason: Bool?
  let includeSafetyAttributes: Bool?
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImageGenerationParameters: Equatable {}

// MARK: - Codable Conformance

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImageGenerationParameters: Encodable {
  enum CodingKeys: String, CodingKey {
    case sampleCount
    case storageURI = "storageUri"
    case negativePrompt
    case aspectRatio
    case safetyFilterLevel = "safetySetting"
    case personGeneration
    case outputOptions
    case addWatermark
    case includeResponsibleAIFilterReason = "includeRaiReason"
    case includeSafetyAttributes
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(sampleCount, forKey: .sampleCount)
    try container.encodeIfPresent(storageURI, forKey: .storageURI)
    try container.encodeIfPresent(negativePrompt, forKey: .negativePrompt)
    try container.encodeIfPresent(aspectRatio, forKey: .aspectRatio)
    try container.encodeIfPresent(safetyFilterLevel, forKey: .safetyFilterLevel)
    try container.encodeIfPresent(personGeneration, forKey: .personGeneration)
    try container.encodeIfPresent(outputOptions, forKey: .outputOptions)
    try container.encodeIfPresent(addWatermark, forKey: .addWatermark)
    try container.encodeIfPresent(
      includeResponsibleAIFilterReason,
      forKey: .includeResponsibleAIFilterReason
    )
    try container.encodeIfPresent(includeSafetyAttributes, forKey: .includeSafetyAttributes)
  }
}
