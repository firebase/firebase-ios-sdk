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

@preconcurrency import FirebaseCore
internal import FirebaseCoreExtension
import Foundation
import XCTest

@testable import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
class VertexComponentTests: XCTestCase {
  static let projectID = "test-project-id"
  static let apiKey = "test-api-key"
  static let options = {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = VertexComponentTests.projectID
    options.apiKey = VertexComponentTests.apiKey

    return options
  }()

  static let app = FirebaseApp(instanceWithName: "test", options: options)

  let location = "test-location"
  let modelName = "test-model-name"
  let systemInstruction = ModelContent(role: "system", parts: "test-system-instruction-prompt")

  override class func setUp() {
    FirebaseApp.configure(options: options)
    guard FirebaseApp.app() != nil else {
      fatalError("The default app does not exist.")
    }
  }

  /// Test that the objc class is available for the component system to update the user agent.
  func testComponentsBeingRegistered() throws {
    XCTAssertNotNil(NSClassFromString("FIRVertexAIComponent"))
  }

  /// Tests that a vertex instance can be created properly using the default Firebase app.
  func testVertexInstanceCreation_defaultApp() throws {
    let vertex = FirebaseAI.firebaseAI(backend: .vertexAI())

    XCTAssertNotNil(vertex)
    XCTAssertEqual(vertex.firebaseInfo.projectID, VertexComponentTests.projectID)
    XCTAssertEqual(vertex.firebaseInfo.apiKey, VertexComponentTests.apiKey)
    XCTAssertEqual(
      vertex.apiConfig.service, .vertexAI(endpoint: .firebaseProxyProd, location: "us-central1")
    )
    XCTAssertEqual(vertex.apiConfig.service.endpoint, .firebaseProxyProd)
    XCTAssertEqual(vertex.apiConfig.version, .v1beta)
  }

  /// Tests that a vertex instance can be created properly using the default Firebase app and custom
  /// location.
  func testVertexInstanceCreation_defaultApp_customLocation() throws {
    let vertex = FirebaseAI.firebaseAI(backend: .vertexAI(location: location))

    XCTAssertNotNil(vertex)
    XCTAssertEqual(vertex.firebaseInfo.projectID, VertexComponentTests.projectID)
    XCTAssertEqual(vertex.firebaseInfo.apiKey, VertexComponentTests.apiKey)
    XCTAssertEqual(
      vertex.apiConfig.service, .vertexAI(endpoint: .firebaseProxyProd, location: location)
    )
    XCTAssertEqual(vertex.apiConfig.service.endpoint, .firebaseProxyProd)
    XCTAssertEqual(vertex.apiConfig.version, .v1beta)
  }

  /// Tests that a vertex instance can be created properly.
  func testVertexInstanceCreation_customApp() throws {
    let vertex = FirebaseAI.firebaseAI(
      app: VertexComponentTests.app,
      backend: .vertexAI(location: location)
    )

    XCTAssertNotNil(vertex)
    XCTAssertEqual(vertex.firebaseInfo.projectID, VertexComponentTests.projectID)
    XCTAssertEqual(vertex.firebaseInfo.apiKey, VertexComponentTests.apiKey)
    XCTAssertEqual(
      vertex.apiConfig.service, .vertexAI(endpoint: .firebaseProxyProd, location: location)
    )
    XCTAssertEqual(vertex.apiConfig.service.endpoint, .firebaseProxyProd)
    XCTAssertEqual(vertex.apiConfig.version, .v1beta)
  }

  /// Tests that Vertex instances are reused properly.
  func testSameAppAndLocation_instanceReused() throws {
    let app = try XCTUnwrap(VertexComponentTests.app)

    let vertex1 = FirebaseAI.firebaseAI(app: app, backend: .vertexAI(location: location))
    let vertex2 = FirebaseAI.firebaseAI(app: app, backend: .vertexAI(location: location))

    // Ensure they're the same instance.
    XCTAssert(vertex1 === vertex2)
  }

  func testSameAppAndDifferentLocation_newInstanceCreated() throws {
    let vertex1 = FirebaseAI.firebaseAI(
      app: VertexComponentTests.app,
      backend: .vertexAI(location: location)
    )
    let vertex2 = FirebaseAI.firebaseAI(
      app: VertexComponentTests.app,
      backend: .vertexAI(location: "differentLocation")
    )

    // Ensure they are different instances.
    XCTAssert(vertex1 !== vertex2)
  }

  func testDifferentAppAndSameLocation_newInstanceCreated() throws {
    FirebaseApp.configure(name: "test-2", options: VertexComponentTests.options)
    let app2 = FirebaseApp(instanceWithName: "test-2", options: VertexComponentTests.options)
    addTeardownBlock { await app2.delete() }

    let vertex1 = FirebaseAI.firebaseAI(
      app: VertexComponentTests.app,
      backend: .vertexAI(location: location)
    )
    let vertex2 = FirebaseAI.firebaseAI(app: app2, backend: .vertexAI(location: location))

    XCTAssert(VertexComponentTests.app != app2)
    XCTAssert(vertex1 !== vertex2) // Ensure they are different instances.
  }

  func testDifferentAppAndDifferentLocation_newInstanceCreated() throws {
    FirebaseApp.configure(name: "test-2", options: VertexComponentTests.options)
    let app2 = FirebaseApp(instanceWithName: "test-2", options: VertexComponentTests.options)
    addTeardownBlock { await app2.delete() }

    let vertex1 = FirebaseAI.firebaseAI(
      app: VertexComponentTests.app,
      backend: .vertexAI(location: location)
    )
    let vertex2 = FirebaseAI.firebaseAI(
      app: app2,
      backend: .vertexAI(location: "differentLocation")
    )

    XCTAssert(VertexComponentTests.app != app2)
    XCTAssert(vertex1 !== vertex2) // Ensure they are different instances.
  }

  func testSameAppAndDifferentAPI_newInstanceCreated() throws {
    let vertex1 = FirebaseAI.createInstance(
      app: VertexComponentTests.app,
      apiConfig: APIConfig(
        service: .vertexAI(endpoint: .firebaseProxyProd, location: location),
        version: .v1beta
      ),
      useLimitedUseAppCheckTokens: false
    )
    let vertex2 = FirebaseAI.createInstance(
      app: VertexComponentTests.app,
      apiConfig: APIConfig(
        service: .vertexAI(endpoint: .firebaseProxyProd, location: location), version: .v1
      ),
      useLimitedUseAppCheckTokens: false
    )

    // Ensure they are different instances.
    XCTAssert(vertex1 !== vertex2)
  }

  /// Test that vertex instances get deallocated.
  func testVertexLifecycle() throws {
    weak var weakApp: FirebaseApp?
    weak var weakVertex: FirebaseAI?
    try autoreleasepool {
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.projectID = VertexComponentTests.projectID
      options.apiKey = VertexComponentTests.apiKey
      let app1 = FirebaseApp(instanceWithName: "transitory app", options: options)
      weakApp = try XCTUnwrap(app1)
      let vertex = FirebaseAI(
        app: app1,
        apiConfig: APIConfig(
          service: .vertexAI(endpoint: .firebaseProxyProd, location: "transitory location"),
          version: .v1beta
        ),
        useLimitedUseAppCheckTokens: false
      )
      weakVertex = vertex
      XCTAssertNotNil(weakVertex)
    }
    XCTAssertNil(weakApp)
    XCTAssertNil(weakVertex)
  }

  func testModelResourceName_vertexAI() throws {
    let app = try XCTUnwrap(VertexComponentTests.app)
    let location = "test-location"
    let vertex = FirebaseAI.firebaseAI(app: app, backend: .vertexAI(location: location))
    let model = "test-model-name"
    let projectID = vertex.firebaseInfo.projectID

    let modelResourceName = vertex.modelResourceName(modelName: model)

    XCTAssertEqual(
      modelResourceName,
      "projects/\(projectID)/locations/\(location)/publishers/google/models/\(model)"
    )
  }

  func testModelResourceName_developerAPI_generativeLanguage() throws {
    let app = try XCTUnwrap(VertexComponentTests.app)
    let apiConfig = APIConfig(service: .googleAI(endpoint: .googleAIBypassProxy), version: .v1beta)
    let vertex = FirebaseAI.createInstance(
      app: app, apiConfig: apiConfig, useLimitedUseAppCheckTokens: false
    )
    let model = "test-model-name"

    let modelResourceName = vertex.modelResourceName(modelName: model)

    XCTAssertEqual(modelResourceName, "models/\(model)")
  }

  func testModelResourceName_developerAPI_firebaseVertexAI() throws {
    let app = try XCTUnwrap(VertexComponentTests.app)
    let apiConfig = APIConfig(
      service: .googleAI(endpoint: .firebaseProxyStaging),
      version: .v1beta
    )
    let vertex = FirebaseAI.createInstance(
      app: app, apiConfig: apiConfig, useLimitedUseAppCheckTokens: false
    )
    let model = "test-model-name"
    let projectID = vertex.firebaseInfo.projectID

    let modelResourceName = vertex.modelResourceName(modelName: model)

    XCTAssertEqual(modelResourceName, "projects/\(projectID)/models/\(model)")
  }

  func testGenerativeModel_vertexAI_defaultLocation() async throws {
    let app = try XCTUnwrap(VertexComponentTests.app)
    let vertex = FirebaseAI.firebaseAI(app: app, backend: .vertexAI())
    let modelResourceName = vertex.modelResourceName(modelName: modelName)
    let expectedSystemInstruction = ModelContent(role: nil, parts: systemInstruction.parts)

    let generativeModel = vertex.generativeModel(
      modelName: modelName, systemInstruction: systemInstruction
    )

    XCTAssertEqual(generativeModel.modelResourceName, modelResourceName)
    XCTAssertEqual(generativeModel.systemInstruction, expectedSystemInstruction)
    XCTAssertEqual(generativeModel.apiConfig, FirebaseAI.defaultVertexAIAPIConfig)
  }

  func testGenerativeModel_vertexAI_customLocation() async throws {
    let app = try XCTUnwrap(VertexComponentTests.app)
    let vertex = FirebaseAI.firebaseAI(app: app, backend: .vertexAI(location: location))
    let modelResourceName = vertex.modelResourceName(modelName: modelName)
    let expectedAPIConfig = APIConfig(
      service: .vertexAI(endpoint: .firebaseProxyProd, location: location), version: .v1beta
    )
    let expectedSystemInstruction = ModelContent(role: nil, parts: systemInstruction.parts)

    let generativeModel = vertex.generativeModel(
      modelName: modelName, systemInstruction: systemInstruction
    )

    XCTAssertEqual(generativeModel.modelResourceName, modelResourceName)
    XCTAssertEqual(generativeModel.systemInstruction, expectedSystemInstruction)
    XCTAssertEqual(generativeModel.apiConfig, expectedAPIConfig)
  }

  func testGenerativeModel_developerAPI() async throws {
    let app = try XCTUnwrap(VertexComponentTests.app)
    let apiConfig = APIConfig(
      service: .googleAI(endpoint: .firebaseProxyStaging),
      version: .v1beta
    )
    let vertex = FirebaseAI.createInstance(
      app: app, apiConfig: apiConfig, useLimitedUseAppCheckTokens: false
    )
    let modelResourceName = vertex.modelResourceName(modelName: modelName)
    let expectedSystemInstruction = ModelContent(role: nil, parts: systemInstruction.parts)

    let generativeModel = vertex.generativeModel(
      modelName: modelName,
      systemInstruction: systemInstruction
    )

    XCTAssertEqual(generativeModel.modelResourceName, modelResourceName)
    XCTAssertEqual(generativeModel.systemInstruction, expectedSystemInstruction)
    XCTAssertEqual(generativeModel.apiConfig, apiConfig)
  }
}
