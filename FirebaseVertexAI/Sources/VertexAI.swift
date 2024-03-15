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

import FirebaseAppCheckInterop
import FirebaseCore
import Foundation

// Avoids exposing internal FirebaseCore APIs to Swift users.
@_implementationOnly import FirebaseCoreExtension

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
@objc(FIRVertexAI)
open class VertexAI: NSObject {
  // MARK: - Public APIs

  /// Returns an instance of `GoogleGenerativeAI.GenerativeModel` that uses the Vertex AI API.
  ///
  /// This instance is configured with the default `FirebaseApp`.
  public static func generativeModel(modelName: String, location: String,
                                     requestOptions: RequestOptions = RequestOptions())
    -> GenerativeModel {
    guard let app = FirebaseApp.app() else {
      fatalError("No instance of the default Firebase app was found.")
    }
    return generativeModel(app: app, modelName: modelName, location: location)
  }

  /// Returns an instance of `GoogleGenerativeAI.GenerativeModel` that uses the Vertex AI API.
  public static func generativeModel(app: FirebaseApp, modelName: String,
                                     location: String,
                                     requestOptions: RequestOptions = RequestOptions())
    -> GenerativeModel {
    guard let provider = ComponentType<VertexAIProvider>.instance(for: VertexAIProvider.self,
                                                                  in: app.container) else {
      fatalError("No \(VertexAIProvider.self) instance found for Firebase app: \(app.name)")
    }
    let modelResourceName = modelResourceName(app: app, modelName: modelName, location: location)
    let vertexAI = provider.vertexAI(
      for: app,
      location: location,
      modelResourceName: modelResourceName,
      requestOptions: requestOptions
    )

    return vertexAI.model
  }

  // MARK: - Internal

  let location: String

  let modelResouceName: String

  // MARK: - Private

  /// The `FirebaseApp` associated with this `VertexAI` instance.
  private let app: FirebaseApp

  private let appCheck: AppCheckInterop?

  lazy var model: GenerativeModel = {
    guard let apiKey = app.options.apiKey else {
      fatalError("The Firebase app named \"\(app.name)\" has no API key in its configuration.")
    }
    return GenerativeModel(
      name: modelResouceName,
      apiKey: apiKey,
      // TODO: Consider adding RequestOptions to public API.
      requestOptions: RequestOptions(),
      appCheck: appCheck
    )
  }()

  init(app: FirebaseApp, location: String, modelResourceName: String) {
    self.app = app
    appCheck = ComponentType<AppCheckInterop>.instance(for: AppCheckInterop.self, in: app.container)
    self.location = location
    modelResouceName = modelResourceName
  }

  private static func modelResourceName(app: FirebaseApp, modelName: String,
                                        location: String) -> String {
    if modelName.contains("/") {
      return modelName
    }
    guard let projectID = app.options.projectID else {
      fatalError("The Firebase app named \"\(app.name)\" has no project ID in its configuration.")
    }
    guard !location.isEmpty else {
      fatalError("""
      No location specified; see
      https://cloud.google.com/vertex-ai/generative-ai/docs/learn/locations#available-regions for a
      list of available regions.
      """)
    }

    return "projects/\(projectID)/locations/\(location)/publishers/google/models/\(modelName)"
  }
}
