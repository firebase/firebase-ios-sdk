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
import Testing

@testable import GeminiAPIClient

@Suite("EndpointConfiguration Tests")
struct EndpointConfigurationTests {
  private static let host = "generativelanguage.googleapis.com"
  private static let apiVersion = "v1beta"
  private static let modelResource = ModelResource(
    modelID: "gemini-3.8-flash",
    urlResourceName: "models/gemini-3.8-flash",
    payloadResourceName: "models/gemini-3.8-flash"
  )

  @Test
  func defaultInitialization() {
    let endpoint = EndpointConfiguration(
      host: Self.host,
      apiVersion: Self.apiVersion
    )

    #expect(endpoint.scheme == "https")
    #expect(endpoint.host == Self.host)
    #expect(endpoint.port == nil)
    #expect(endpoint.apiVersion == Self.apiVersion)
  }

  @Test
  func customSchemeAndPortInitialization() {
    let scheme = "http"
    let host = "localhost"
    let port = 8080
    let endpoint = EndpointConfiguration(
      scheme: scheme,
      host: host,
      port: port,
      apiVersion: Self.apiVersion
    )

    #expect(endpoint.scheme == scheme)
    #expect(endpoint.host == host)
    #expect(endpoint.port == port)
    #expect(endpoint.apiVersion == Self.apiVersion)
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func urlAssemblyStandard() throws {
    let endpoint = EndpointConfiguration(
      host: Self.host,
      apiVersion: Self.apiVersion
    )
    let client = GeminiAPIClient(
      modelResource: Self.modelResource,
      endpointConfiguration: endpoint
    )
    let action = "streamGenerateContent"

    let url = try client.makeRequestURL(
      action: action,
      queryItems: [URLQueryItem(name: "alt", value: "sse")]
    )

    let expectedPath = "\(Self.modelResource.urlResourceName):\(action)"
    let expectedURL = "https://\(Self.host)/\(Self.apiVersion)/\(expectedPath)?alt=sse"
    #expect(url.absoluteString == expectedURL)
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func urlAssemblySanitizesSlashes() throws {
    let endpoint = EndpointConfiguration(
      host: Self.host,
      apiVersion: "/\(Self.apiVersion)/"
    )
    let modelResource = ModelResource(
      modelID: "gemini-3.8-flash",
      urlResourceName: "/\(Self.modelResource.urlResourceName)/",
      payloadResourceName: "models/gemini-3.8-flash"
    )
    let client = GeminiAPIClient(
      modelResource: modelResource,
      endpointConfiguration: endpoint
    )
    let action = "countTokens"

    let url = try client.makeRequestURL(action: action)

    let expectedPath = "\(Self.modelResource.urlResourceName):\(action)"
    let expectedURL = "https://\(Self.host)/\(Self.apiVersion)/\(expectedPath)"
    #expect(url.absoluteString == expectedURL)
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func urlAssemblyWithCustomPort() throws {
    let scheme = "http"
    let host = "localhost"
    let port = 8080
    let endpoint = EndpointConfiguration(
      scheme: scheme,
      host: host,
      port: port,
      apiVersion: Self.apiVersion
    )
    let client = GeminiAPIClient(
      modelResource: Self.modelResource,
      endpointConfiguration: endpoint
    )
    let action = "streamGenerateContent"

    let url = try client.makeRequestURL(action: action)

    let expectedPath = "\(Self.modelResource.urlResourceName):\(action)"
    let expectedURL = "\(scheme)://\(host):\(port)/\(Self.apiVersion)/\(expectedPath)"
    #expect(url.absoluteString == expectedURL)
  }

  @Test
  func equalityAndHashing() {
    let endpoint1 = EndpointConfiguration(
      host: Self.host,
      apiVersion: Self.apiVersion
    )
    let endpoint2 = EndpointConfiguration(
      host: Self.host,
      apiVersion: Self.apiVersion
    )
    let endpoint3 = EndpointConfiguration(
      host: "firebasevertexai.googleapis.com",
      apiVersion: Self.apiVersion
    )

    #expect(endpoint1 == endpoint2)
    #expect(endpoint1 != endpoint3)
    #expect(endpoint1.hashValue == endpoint2.hashValue)
  }
}
