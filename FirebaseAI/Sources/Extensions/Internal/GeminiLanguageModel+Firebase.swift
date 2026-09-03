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

#if compiler(>=6.4) && canImport(FoundationModels) && canImport(GeminiLanguageModel)
  import Foundation
  import GeminiAPIClient
  import GeminiLanguageModel

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiLanguageModel {
    init(name: String, firebaseAI: FirebaseAI) {
      let endpointURL = firebaseAI.apiConfig.service.endpoint.rawValue
      guard let urlComponents = URLComponents(string: endpointURL) else {
        preconditionFailure("Invalid Gemini API URL: \(endpointURL)")
      }
      guard let host = urlComponents.host else {
        preconditionFailure("Invalid Gemini API hostname in URL: \(endpointURL)")
      }

      self.init(
        modelResource: ModelResource(
          modelID: name,
          urlResourceName: firebaseAI.modelResourceName(modelName: name),
          payloadResourceName: "models/\(name)"
        ),
        endpointConfiguration: EndpointConfiguration(
          host: host,
          port: urlComponents.port,
          apiVersion: firebaseAI.apiConfig.version.rawValue
        ),
        headerProvider: {
          let firebaseInfo = firebaseAI.firebaseInfo
          var headers = ["x-goog-api-key": firebaseInfo.apiKey]

          if let bundleID = Bundle.main.bundleIdentifier {
            headers["x-ios-bundle-identifier"] = bundleID
          }

          let apiClientHeaders = [
            GenerativeAIService.languageTag,
            GenerativeAIService.firebaseVersionTag,
          ]
          headers["x-goog-api-client"] = apiClientHeaders.joined(separator: " ")

          if let appCheck = firebaseInfo.appCheck {
            let tokenResult = try await appCheck.fetchAppCheckToken(
              limitedUse: firebaseInfo.useLimitedUseAppCheckTokens,
              domain: "\(Self.self)"
            )
            headers["X-Firebase-AppCheck"] = tokenResult.token
            if let error = tokenResult.error {
              AILog.error(
                code: .appCheckTokenFetchFailed,
                "Failed to fetch AppCheck token. Error: \(error)"
              )
            }
          }

          if let auth = firebaseInfo.auth,
             let authToken = try await auth.getToken(forcingRefresh: false) {
            headers["Authorization"] = "Firebase \(authToken)"
          }

          if firebaseInfo.app.isDataCollectionDefaultEnabled {
            headers["X-Firebase-AppId"] = firebaseInfo.firebaseAppID
            if let bundleInfo = Bundle.main.infoDictionary,
               let appVersion = bundleInfo["CFBundleShortVersionString"] as? String {
              headers["X-Firebase-AppVersion"] = appVersion
            }
          }

          return headers
        },
        configuration: .ephemeral
      )
    }
  }
#endif // compiler(>=6.4) && canImport(FoundationModels) && canImport(GeminiLanguageModel)
