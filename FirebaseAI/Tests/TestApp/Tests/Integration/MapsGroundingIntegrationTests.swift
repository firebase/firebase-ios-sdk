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

import CoreLocation
import FirebaseAI
import FirebaseAITestApp
import Testing
import XCTest

@Suite(.serialized)
struct MapsGroundingIntegrationTests {
  @Test(
    "generateContent with Google Maps returns grounding metadata",
    arguments: InstanceConfig.allConfigs
  )
  func generateContent_withGoogleMaps_succeeds(_ config: InstanceConfig) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_Flash,
      tools: [.googleMaps()]
    )
    let prompt = "Where is a good place to grab a coffee near Alameda, CA?"

    let response = try await model.generateContent(prompt)

    let candidate = try #require(response.candidates.first)
    let groundingMetadata = try #require(candidate.groundingMetadata)

    let mapChunks = groundingMetadata.groundingChunks.compactMap { $0.maps }
    #expect(!mapChunks.isEmpty)

    for mapsChunk in mapChunks {
      #expect(mapsChunk.url != nil)
      let title = try XCTUnwrap(mapsChunk.title)
      #expect(!title.isEmpty)
      let placeID = try XCTUnwrap(mapsChunk.placeID)
      #expect(!placeID.isEmpty)
    }
  }

  @Test(
    "generateContent with Google Maps and RetrievalConfig returns grounding metadata",
    arguments: InstanceConfig.allConfigs
  )
  func generateContent_withGoogleMapsAndRetrievalConfig_succeeds(_ config: InstanceConfig) async throws {
    let toolConfig = ToolConfig(
      retrievalConfig: RetrievalConfig(
        latLng: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431)
      )
    )
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_Flash,
      tools: [.googleMaps()],
      toolConfig: toolConfig
    )
    let prompt = "Find bookstores in my area."

    let response = try await model.generateContent(prompt)

    let candidate = try #require(response.candidates.first)
    let groundingMetadata = try #require(candidate.groundingMetadata)

    let mapChunks = groundingMetadata.groundingChunks.compactMap { $0.maps }
    #expect(!mapChunks.isEmpty)

    for mapsChunk in mapChunks {
      #expect(mapsChunk.url != nil)
      let title = try XCTUnwrap(mapsChunk.title)
      #expect(!title.isEmpty)
      let placeID = try XCTUnwrap(mapsChunk.placeID)
      #expect(!placeID.isEmpty)
    }
  }

  @Test(
    "generateContent with Google Maps and languageCode returns grounding metadata",
    arguments: InstanceConfig.allConfigs
  )
  func generateContent_withGoogleMapsAndLanguageConfig_succeeds(_ config: InstanceConfig) async throws {
    let toolConfig = ToolConfig(
      retrievalConfig: RetrievalConfig(
        languageCode: "es"
      )
    )
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2_5_Flash,
      tools: [.googleMaps()],
      toolConfig: toolConfig
    )
    let prompt = "Where is a good place to grab a coffee near Alameda, CA?"

    let response = try await model.generateContent(prompt)

    let candidate = try #require(response.candidates.first)
    let groundingMetadata = try #require(candidate.groundingMetadata)

    let mapChunks = groundingMetadata.groundingChunks.compactMap { $0.maps }
    #expect(!mapChunks.isEmpty)

    for mapsChunk in mapChunks {
      #expect(mapsChunk.url != nil)
      let title = try XCTUnwrap(mapsChunk.title)
      #expect(!title.isEmpty)
      let placeID = try XCTUnwrap(mapsChunk.placeID)
      #expect(!placeID.isEmpty)
    }
  }
}
