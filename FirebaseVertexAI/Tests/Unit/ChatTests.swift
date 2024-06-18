// Copyright 2023 Google LLC
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
import XCTest

@testable import FirebaseVertexAI

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
final class ChatTests: XCTestCase {
  var urlSession: URLSession!

  override func setUp() {
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [MockURLProtocol.self]
    urlSession = URLSession(configuration: configuration)
  }

  override func tearDown() {
    MockURLProtocol.requestHandler = nil
  }

  func testMergingText() async throws {
    let fileURL = try XCTUnwrap(Bundle.module.url(
      forResource: "streaming-success-basic-reply-long",
      withExtension: "txt"
    ))

    MockURLProtocol.requestHandler = { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, fileURL.lines)
    }

    let model = GenerativeModel(
      name: "my-model",
      projectID: "my-project-id",
      apiKey: "API_KEY",
      tools: nil,
      requestOptions: RequestOptions(),
      appCheck: nil,
      auth: nil,
      urlSession: urlSession
    )
    let chat = Chat(model: model, history: [])
    let input = "Test input"
    let stream = chat.sendMessageStream(input)

    // Ensure the values are parsed correctly
    for try await value in stream {
      XCTAssertNotNil(value.text)
    }

    XCTAssertEqual(chat.history.count, 2)
    XCTAssertEqual(chat.history[0].parts[0].text, input)

    let finalText =
      "**Cats:**\n\n- **Physical Characteristics:**\n  - Size: Cats come in a wide range of sizes, from small breeds like the Singapura to large breeds like the Maine Coon.\n  - Fur: Cats have soft, furry coats that can vary in length and texture depending on the breed.\n  - Eyes: Cats have large, expressive eyes that can be various colors, including green, blue, yellow, and hazel.\n  - Ears: Cats have pointed, erect ears that are sensitive to sound.\n  - Tail: Cats have long, flexible tails that they use for balance and communication.\n\n- **Behavior and Personality:**\n  - Independent: Cats are often described as independent animals that enjoy spending time alone.\n  - Affectionate: Despite their independent nature, cats can be very affectionate and form strong bonds with their owners.\n  - Playful: Cats are naturally playful and enjoy engaging in activities such as chasing toys, climbing, and pouncing.\n  - Curious: Cats are curious creatures that love to explore their surroundings.\n  - Vocal: Cats communicate through a variety of vocalizations, including meows, purrs, hisses, and growls.\n\n- **Health and Care:**\n  - Diet: Cats are obligate carnivores, meaning they require animal-based protein for optimal health.\n  - Grooming: Cats spend a significant amount of time grooming themselves to keep their fur clean and free of mats.\n  - Exercise: Cats need regular exercise to stay healthy and active. This can be achieved through play sessions or access to outdoor space.\n  - Veterinary Care: Regular veterinary checkups are essential for maintaining a cat's health and detecting any potential health issues early on.\n\n**Dogs:**\n\n- **Physical Characteristics:**\n  - Size: Dogs come in a wide range of sizes, from small breeds like the Chihuahua to giant breeds like the Great Dane.\n  - Fur: Dogs have fur coats that can vary in length, texture, and color depending on the breed.\n  - Eyes: Dogs have expressive eyes that can be various colors, including brown, blue, green, and hazel.\n  - Ears: Dogs have floppy or erect ears that are sensitive to sound.\n  - Tail: Dogs have long, wagging tails that they use for communication and expressing emotions.\n\n- **Behavior and Personality:**\n  - Loyal: Dogs are known for their loyalty and devotion to their owners.\n  - Friendly: Dogs are generally friendly and outgoing animals that enjoy interacting with people and other animals.\n  - Playful: Dogs are playful and energetic creatures that love to engage in activities such as fetching, running, and playing with toys.\n  - Trainable: Dogs are highly trainable and can learn a variety of commands and tricks.\n  - Vocal: Dogs communicate through a variety of vocalizations, including barking, howling, whining, and growling.\n\n- **Health and Care:**\n  - Diet: Dogs are omnivores and can eat a variety of foods, including meat, vegetables, and grains.\n  - Grooming: Dogs require regular grooming to keep their fur clean and free of mats. The frequency of grooming depends on the breed and coat type.\n  - Exercise: Dogs need regular exercise to stay healthy and active. The amount of exercise required varies depending on the breed and age of the dog.\n  - Veterinary Care: Regular veterinary checkups are essential for maintaining a dog's health and detecting any potential health issues early on."
    let assembledExpectation = ModelContent(role: "model", parts: finalText)
    XCTAssertEqual(chat.history[0].parts[0].text, input)
    XCTAssertEqual(chat.history[1], assembledExpectation)
  }
}
