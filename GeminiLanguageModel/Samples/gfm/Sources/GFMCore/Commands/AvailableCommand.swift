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

public import ArgumentParser
import Foundation

#if canImport(FoundationModels) && compiler(>=6.4)
  import FoundationModels

  /// Command that checks and prints model availability.
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct AvailableCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
      commandName: "available",
      abstract: "Check model availability."
    )

    @Option(
      name: [.short, .long],
      help: "Model to check (gemini, system); checks all if omitted."
    )
    public var model: ModelChoice?

    @Option(
      name: .long,
      help: "Gemini model ID to check."
    )
    public var geminiModel: String = ModelResolver.defaultGeminiModelID

    @Option(
      name: .long,
      help: "Explicit Gemini API key."
    )
    public var apiKey: String?

    public init() {}

    public func run() async throws {
      let resolver = ModelResolver(
        choice: model ?? .gemini,
        geminiModelID: geminiModel,
        explicitAPIKey: apiKey
      )

      let modelsToCheck: [ModelChoice]
      if let model {
        modelsToCheck = [model]
      } else {
        modelsToCheck = [.system, .gemini]
      }

      var allAvailable = true

      for choice in modelsToCheck {
        let status = resolver.checkAvailability(for: choice)
        switch status {
        case .available:
          print("\(choice.displayName) available")
        case .unavailable(let reason):
          allAvailable = false
          print("\(choice.displayName) unavailable: \(reason)")
        }
      }

      if !allAvailable {
        throw ExitCode.failure
      }
    }
  }
#endif
