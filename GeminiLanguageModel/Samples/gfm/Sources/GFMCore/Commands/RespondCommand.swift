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

import var Darwin.C.STDIN_FILENO
import func Darwin.C.isatty

#if canImport(FoundationModels) && compiler(>=6.4)
  import FoundationModels

  /// Command that generates a response from the selected model for a given prompt.
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct RespondCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
      commandName: "respond",
      abstract: "Generate a response to a prompt."
    )

    @Argument(
      help: "Prompt for the model (reads from stdin if omitted, or combines with stdin when piped)."
    )
    public var prompt: String?

    @Option(
      name: [.short, .long],
      help: "Model to use (gemini, system; default: gemini)."
    )
    public var model: ModelChoice = .gemini

    @Option(
      name: .long,
      help: "Gemini model ID to use when targetting Gemini."
    )
    public var geminiModel: String = ModelResolver.defaultGeminiModelID

    @Option(
      name: .long,
      help: "Explicit Gemini API key."
    )
    public var apiKey: String?

    @Option(
      name: [.short, .long],
      help: "Instructions for the model to follow."
    )
    public var instructions: String?

    @Option(
      name: .long,
      help: "Path to a structured output schema file."
    )
    public var schema: String?

    @Option(
      name: .long,
      help: "Text segment to include in the prompt (repeatable)."
    )
    public var text: [String] = []

    @Option(
      name: .long,
      help: "Built-in tool to enable (current-time; repeatable)."
    )
    public var tool: [String] = []

    @Option(
      name: .long,
      help: "Continue a saved conversation from its transcript."
    )
    public var resume: String?

    @Option(
      name: .long,
      help: "Save transcript to a file after responding."
    )
    public var saveTranscript: String?

    @Flag(
      inversion: .prefixedNo,
      help: "Stream the output as it's generated (default: on)."
    )
    public var stream: Bool = true

    @Flag(
      name: [.short, .long],
      help: "Use greedy sampling."
    )
    public var greedy: Bool = false

    @Flag(
      name: [.short, .long],
      help: "Print verbose output."
    )
    public var verbose: Bool = false

    public init() {}

    public func run() async throws {
      let resolvedPrompt = try resolvePrompt()

      let resolver = ModelResolver(
        choice: model,
        geminiModelID: geminiModel,
        explicitAPIKey: apiKey
      )
      let languageModel = try resolver.makeModel()

      var tools: [any Tool] = []
      for toolName in tool {
        if toolName == "current-time" || toolName == "current_time" {
          tools.append(CurrentTimeTool())
        } else {
          throw ValidationError("Unsupported tool '\(toolName)'. Available tools: current-time")
        }
      }

      let sessionManager = SessionManager()
      let session: LanguageModelSession

      if let resume {
        let transcript = try sessionManager.loadSession(nameOrPath: resume)
        if instructions != nil {
          throw ValidationError(
            "Cannot specify both a saved transcript and --instructions. The transcript already contains its instructions."
          )
        }
        session = LanguageModelSession(model: languageModel, tools: tools, transcript: transcript)
      } else {
        session = LanguageModelSession(
          model: languageModel,
          tools: tools,
          instructions: instructions
        )
      }

      var options = GenerationOptions()
      if greedy {
        options.temperature = 0.0
      }

      if let schemaPath = schema {
        let schemaURL = URL(fileURLWithPath: NSString(string: schemaPath).expandingTildeInPath)
        let schemaData = try Data(contentsOf: schemaURL)
        let genSchema = try JSONDecoder().decode(GenerationSchema.self, from: schemaData)

        if stream {
          let responseStream = session.streamResponse(
            to: resolvedPrompt,
            schema: genSchema,
            options: options
          )
          var printed = ""
          for try await snapshot in responseStream {
            let current = snapshot.content.jsonString
            if current.count > printed.count {
              let diff = current.dropFirst(printed.count)
              print(diff, terminator: "")
              fflush(stdout)
              printed = current
            }
          }
          print()
        } else {
          let response = try await session.respond(
            to: resolvedPrompt,
            schema: genSchema,
            options: options
          )
          print(response.content.jsonString)
        }
      } else {
        if stream {
          let responseStream = session.streamResponse(
            to: resolvedPrompt,
            options: options
          )
          var printed = ""
          for try await snapshot in responseStream {
            let current = snapshot.content
            if current.count > printed.count {
              let diff = current.dropFirst(printed.count)
              print(diff, terminator: "")
              fflush(stdout)
              printed = current
            }
          }
          print()
        } else {
          let response = try await session.respond(
            to: resolvedPrompt,
            options: options
          )
          print(response.content)
        }
      }

      if let saveTranscript {
        try sessionManager.saveSession(transcript: session.transcript, nameOrPath: saveTranscript)
      }
    }

    func resolvePrompt(
      stdinReader: () throws -> String? = {
        guard isatty(STDIN_FILENO) == 0 else { return nil }
        guard let stdinData = try? FileHandle.standardInput.readToEnd() else { return nil }
        guard let text = String(data: stdinData, encoding: .utf8) else {
          throw ValidationError(
            "Standard input was not valid UTF-8. Pipe UTF-8 encoded text only."
          )
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
      }
    ) throws -> String {
      var segments: [String] = []
      if let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        segments.append(prompt)
      }
      segments.append(contentsOf: text)

      let stdinContent = try stdinReader()

      if let stdinContent, !segments.isEmpty {
        return stdinContent + "\n\n" + segments.joined(separator: "\n")
      } else if let stdinContent {
        return stdinContent
      } else if !segments.isEmpty {
        return segments.joined(separator: "\n")
      }

      throw ValidationError("Prompt must be provided as an argument or via standard input.")
    }
  }
#endif
