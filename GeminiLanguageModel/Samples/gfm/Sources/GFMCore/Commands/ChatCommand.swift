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

  /// Command that starts an interactive multi-turn chat session.
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct ChatCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
      commandName: "chat",
      abstract: "Start an interactive chat session."
    )

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
      name: [.customLong("api-variant"), .customLong("api")],
      help: "Gemini API variant to use (generate-content, interactions; default: generate-content)."
    )
    public var apiVariant: APIVariantChoice = .generateContent

    @Option(
      name: .long,
      help: "Explicit Gemini API key."
    )
    public var apiKey: String?

    @Option(
      name: [.short, .long],
      help: "Instructions for the model."
    )
    public var instructions: String?

    @Option(
      name: [.short, .customLong("resume")],
      help: "Resume a saved chat session."
    )
    public var resume: String?

    @Flag(
      name: .long,
      help: "Continue the most recent chat session."
    )
    public var `continue`: Bool = false

    @Option(
      name: .long,
      help: "Built-in tool to enable (current-time; repeatable)."
    )
    public var tool: [String] = []

    public init() {}

    public func run() async throws {
      let resolver = ModelResolver(
        choice: model,
        geminiModelID: geminiModel,
        apiVariant: apiVariant,
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
      let sessionName: String
      var session: LanguageModelSession

      if `continue` {
        guard let recentName = try sessionManager.mostRecentSessionName() else {
          throw ValidationError("No saved sessions found in ~/.fm/sessions/")
        }
        sessionName = recentName
        let transcript = try sessionManager.loadSession(nameOrPath: sessionName)
        session = LanguageModelSession(model: languageModel, tools: tools, transcript: transcript)
        print("Resumed session '\(sessionName)'.")
      } else if let resume {
        sessionName = resume
        let transcript = try sessionManager.loadSession(nameOrPath: sessionName)
        session = LanguageModelSession(model: languageModel, tools: tools, transcript: transcript)
        print("Resumed session '\(sessionName)'.")
      } else {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        sessionName = "session-\(formatter.string(from: Date()))"
        session = LanguageModelSession(
          model: languageModel,
          tools: tools,
          instructions: instructions
        )
      }

      print("Session: \(sessionName). Type /help for available commands.\n")

      while true {
        print("> ", terminator: "")
        fflush(stdout)

        guard let line = readLine() else {
          print("\nExiting chat session.")
          break
        }

        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
          continue
        }

        if trimmed.hasPrefix("/") {
          let shouldExit = try handleSlashCommand(
            trimmed,
            sessionName: sessionName,
            sessionManager: sessionManager,
            session: &session,
            languageModel: languageModel,
            tools: tools
          )
          if shouldExit {
            break
          }
          continue
        }

        let responseStream = session.streamResponse(to: trimmed)
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
        print("\n")

        try? sessionManager.saveSession(transcript: session.transcript, nameOrPath: sessionName)
      }
    }

    private func handleSlashCommand(
      _ command: String,
      sessionName: String,
      sessionManager: SessionManager,
      session: inout LanguageModelSession,
      languageModel: any LanguageModel,
      tools: [any Tool]
    ) throws -> Bool {
      let parts = command.split(separator: " ", maxSplits: 1).map(String.init)
      let cmd = parts.first ?? command

      switch cmd {
      case "/help":
        print("Available commands:")
        print("  /exit, /quit   Save and exit the current chat session")
        print("  /clear         Clear session history and reset context")
        print("  /sessions      List all saved sessions in ~/.fm/sessions/")
        print("  /help          Show this help message\n")
        return false

      case "/exit", "/quit":
        try? sessionManager.saveSession(transcript: session.transcript, nameOrPath: sessionName)
        print("Saved session to ~/.fm/sessions/\(sessionName).json. Goodbye!")
        return true

      case "/clear":
        session = LanguageModelSession(
          model: languageModel,
          tools: tools,
          instructions: instructions
        )
        try? sessionManager.saveSession(transcript: session.transcript, nameOrPath: sessionName)
        print("Session history cleared.\n")
        return false

      case "/sessions":
        let sessions = try sessionManager.listSessionNames()
        if sessions.isEmpty {
          print("No saved sessions found.\n")
        } else {
          print("Saved sessions:")
          for s in sessions {
            print("  \(s)")
          }
          print()
        }
        return false

      default:
        print("Unknown command '\(cmd)'. Type /help for available commands.\n")
        return false
      }
    }
  }
#endif
