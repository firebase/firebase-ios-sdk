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

#if compiler(>=6.2.3)

  import Foundation
  #if canImport(FoundationModels)
    import FoundationModels
  #endif

  extension FirebaseAI {
    // TODO: Make `Transcript` public when API is reviewed.
    struct Transcript: Sendable, Equatable {
      var entries: [Transcript.Entry]

      public init(entries: some Sequence<Transcript.Entry> = []) {
        self.entries = Array(entries)
      }

      init(contents: [ModelContent]) {
        var entries = [Transcript.Entry]()
        var expectedRole = "user"

        for content in contents {
          let role = content.role ?? expectedRole

          var segments = [Transcript.Segment]()

          for part in content.internalParts {
            let isThought = part.isThought ?? false
            if let partData = part.data {
              switch partData {
              case let .text(string):
                if isThought {
                  segments.append(.thought(Transcript.ThoughtSegment(content: string)))
                } else {
                  segments.append(.text(Transcript.TextSegment(content: string)))
                }
              default:
                print("Warning: ignored unsupported part type: \(partData)")
                continue
              }
            }
          }

          if role == "user" {
            entries.append(.prompt(Transcript.Prompt(segments: segments)))
            expectedRole = "model"
          } else if role == "model" {
            entries.append(.response(Transcript.Response(assetIDs: [], segments: segments)))
            expectedRole = "user"
          }
        }

        self.entries = entries
      }

      @nonexhaustive
      public enum Entry: Sendable, Equatable {
        case prompt(Transcript.Prompt)
        case response(Transcript.Response)
      }

      @nonexhaustive
      public enum Segment: Sendable, Equatable {
        case text(Transcript.TextSegment)
        case structure(Transcript.StructuredSegment)
        case thought(Transcript.ThoughtSegment)
      }

      public struct TextSegment: Sendable, Equatable, Identifiable {
        public var id: String
        public var content: String

        public init(id: String = UUID().uuidString, content: String) {
          self.id = id
          self.content = content
        }
      }

      public struct StructuredSegment: Sendable, Equatable, Identifiable {
        public var id: String
        public var source: String
        public var content: FirebaseAI.GeneratedContent

        public init(id: String = UUID().uuidString, source: String,
                    content: FirebaseAI.GeneratedContent) {
          self.id = id
          self.source = source
          self.content = content
        }
      }

      public struct ThoughtSegment: Sendable, Equatable, Identifiable {
        public var id: String
        public var content: String

        public init(id: String = UUID().uuidString, content: String) {
          self.id = id
          self.content = content
        }
      }

      public struct Prompt: Sendable, Equatable, Identifiable {
        public var id: String
        public var segments: [Transcript.Segment]
        public var options: GenerationConfig
        public var responseFormat: Transcript.ResponseFormat?

        public init(id: String = UUID().uuidString, segments: [Transcript.Segment],
                    options: GenerationConfig = GenerationConfig(),
                    responseFormat: Transcript.ResponseFormat? = nil) {
          self.id = id
          self.segments = segments
          self.options = options
          self.responseFormat = responseFormat
        }
      }

      public struct ResponseFormat: Sendable, Equatable {
        public internal(set) var name: String

        #if canImport(FoundationModels)
          @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
          @available(tvOS, unavailable)
          @available(watchOS, unavailable)
          public init<Content>(type: Content.Type) where Content: FoundationModels.Generable {
            name = FoundationModels.Transcript.ResponseFormat(type: type).name
          }
        #endif // canImport(FoundationModels)

        public init(schema: FirebaseAI.GenerationSchema) {
          #if canImport(FoundationModels)
            if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
              name = FoundationModels.Transcript.ResponseFormat(schema: schema.generationSchema)
                .name
              return
            }
          #endif // canImport(FoundationModels)

          // TODO: Set name from FirebaseAI.GenerationSchema when implemented for iOS 15+.
          name = "GeneratedContent"
        }
      }

      public struct Response: Sendable, Equatable, Identifiable {
        public var id: String
        public var assetIDs: [String]
        public var segments: [Transcript.Segment]

        public init(id: String = UUID().uuidString, assetIDs: [String],
                    segments: [Transcript.Segment]) {
          self.id = id
          self.assetIDs = assetIDs
          self.segments = segments
        }
      }
    }
  }

#endif // compiler(>=6.2.3)
