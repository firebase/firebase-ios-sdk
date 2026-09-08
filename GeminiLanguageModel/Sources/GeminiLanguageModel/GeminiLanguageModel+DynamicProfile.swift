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

#if canImport(FoundationModels) && compiler(>=6.4)
  public import FoundationModels

  /// Property key for storing Gemini thought summaries in `SessionPropertyValues`.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  enum GeminiThoughtSummaryPropertyKey: SessionPropertyKey {
    /// The default value when no thought summary has been produced.
    static let defaultValue: String? = nil
  }

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension SessionPropertyValues {
    /// The thought summary produced by the Gemini model during the session, or `nil` if no
    /// thought summary was produced.
    ///
    /// When using a dynamic profile configured with `.geminiThinking()`, this property is
    /// automatically updated as the model reasons and resets at the start of each new turn.
    /// Since `SessionPropertyValues` conforms to `Observable`, SwiftUI views can observe this
    /// property directly:
    ///
    /// ```swift
    /// struct TutorView: View {
    ///   @State var session: LanguageModelSession
    ///
    ///   var body: some View {
    ///     if let thought = session.properties.geminiThoughtSummary {
    ///       Text(thought)
    ///         .font(.caption)
    ///         .foregroundStyle(.secondary)
    ///     }
    ///   }
    /// }
    /// ```
    public var geminiThoughtSummary: String? {
      get { self[GeminiThoughtSummaryPropertyKey.self] }
      set { self[GeminiThoughtSummaryPropertyKey.self] = newValue }
    }
  }

  /// A dynamic profile modifier that configures Gemini thought summaries on prompt entries
  /// and updates the observable thought summary on the session.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  struct GeminiThinkingSummaryProfileModifier: LanguageModelSession.DynamicProfileModifier {
    @SessionProperty(\.history)
    var history

    @SessionProperty(\.geminiThoughtSummary)
    var thoughtSummary

    let mode: GeminiLanguageModel.Thinking.SummaryMode

    /// Creates a new profile modifier with the specified thinking summaries mode.
    ///
    /// - Parameter mode: The mode for returning thought summaries.
    init(summaries mode: GeminiLanguageModel.Thinking.SummaryMode) {
      self.mode = mode
    }

    /// Applies the thinking summary configuration and reasoning observation to the dynamic profile.
    ///
    /// - Parameter content: The dynamic profile content being modified.
    /// - Returns: The modified dynamic profile.
    func body(content: Content) -> some LanguageModelSession.DynamicProfile {
      content
        .onPrompt { prompt in
          guard
            let promptIndex = history.lastIndex(where: {
              guard case .prompt(let entryPrompt) = $0 else { return false }
              return entryPrompt.id == prompt.id
            })
          else {
            return
          }

          var updatedPrompt = prompt
          var metadata =
            updatedPrompt.metadata[GeminiRequestMetadata.metadataKey].flatMap(
              GeminiRequestMetadata.init
            ) ?? GeminiRequestMetadata()
          metadata.thinkingSummaries = mode
          updatedPrompt.metadata[GeminiRequestMetadata.metadataKey] = metadata.generatedContent
          history[promptIndex] = Transcript.Entry.prompt(updatedPrompt)
          thoughtSummary = nil
        }
        .onReasoning { reasoning in
          guard mode != .off else { return }
          let text = reasoning.segments.compactMap { segment in
            if case .text(let textSegment) = segment {
              return textSegment.content
            }
            return nil
          }.joined()
          guard !text.isEmpty else { return }
          if var current = thoughtSummary {
            current.append(text)
            thoughtSummary = current
          } else {
            thoughtSummary = text
          }
        }
    }
  }

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension LanguageModelSession.DynamicProfile {
    /// Configures thought summaries for Gemini models on this dynamic profile.
    ///
    /// Thought summaries produced during generation are automatically recorded to
    /// `session.properties.geminiThoughtSummary`.
    ///
    /// > Note: To configure the reasoning depth, use Apple's `.reasoningLevel` profile modifier with
    /// > `.light`, `.moderate`, or `.deep`.
    ///
    /// - Parameter mode: The thinking summaries mode. Defaults to `.auto`.
    /// - Returns: A dynamic profile configured with the thinking summary setting.
    public func geminiThinking(
      summaries mode: GeminiLanguageModel.Thinking.SummaryMode = .auto
    ) -> some LanguageModelSession.DynamicProfile {
      modifier(GeminiThinkingSummaryProfileModifier(summaries: mode))
    }

    /// Enables thought summaries for Gemini models on this dynamic profile and observes incoming
    /// thought summaries during reasoning.
    ///
    /// > Note: To configure the reasoning depth/budget, use Apple's `.reasoningLevel` profile
    /// > modifier with `.light`, `.moderate`, or `.deep`.
    ///
    /// - Parameter action: A closure called with the complete thought summary text for the
    ///   reasoning entry whenever the model produces reasoning.
    /// - Returns: A dynamic profile configured with the thinking summary setting and reasoning
    ///   observer.
    public func geminiThinking(
      perform action: @Sendable @escaping (String) async throws -> Void
    ) -> some LanguageModelSession.DynamicProfile {
      geminiThinking(summaries: .auto)
        .onReasoning { reasoning in
          let text = reasoning.segments.compactMap { segment in
            if case .text(let textSegment) = segment {
              return textSegment.content
            }
            return nil
          }.joined()
          guard !text.isEmpty else { return }
          try await action(text)
        }
    }
  }

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.Entry {
    /// The concatenated text content of this reasoning entry, or `nil` if this entry is not reasoning
    /// or contains no text content.
    var reasoningText: String? {
      guard case .reasoning(let reasoning) = self else { return nil }
      let text = reasoning.segments.compactMap { segment in
        guard case .text(let textSegment) = segment else { return nil }
        return textSegment.content
      }.joined()
      return text.isEmpty ? nil : text
    }
  }

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension LanguageModelSession.Response {
    /// The concatenated thought summary text generated by the model during this response, or
    /// `nil` if no thought summary was produced.
    ///
    /// ```swift
    /// let response = try await session.respond(to: "What is 17 multiplied by 24?")
    /// if let thought = response.geminiThoughtSummary {
    ///   print(thought)
    /// }
    /// ```
    public var geminiThoughtSummary: String? {
      let texts = transcriptEntries.compactMap(\.reasoningText)
      return texts.isEmpty ? nil : texts.joined()
    }
  }

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension LanguageModelSession.ResponseStream.Snapshot {
    /// The concatenated thought summary text generated so far in this streaming response, or
    /// `nil` if no thought summary has been produced.
    ///
    /// ```swift
    /// for try await snapshot in session.streamResponse(to: "What is 17 multiplied by 24?") {
    ///   if let thought = snapshot.geminiThoughtSummary {
    ///     print("Thinking: \(thought)")
    ///   }
    /// }
    /// ```
    public var geminiThoughtSummary: String? {
      let texts = transcriptEntries.compactMap(\.reasoningText)
      return texts.isEmpty ? nil : texts.joined()
    }
  }

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript {
    /// The concatenated thought summary text recorded in this transcript, or `nil` if no
    /// thought summary exists.
    ///
    /// ```swift
    /// if let thought = session.transcript.geminiThoughtSummary {
    ///   print(thought)
    /// }
    /// ```
    public var geminiThoughtSummary: String? {
      let texts = compactMap(\.reasoningText)
      return texts.isEmpty ? nil : texts.joined()
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
