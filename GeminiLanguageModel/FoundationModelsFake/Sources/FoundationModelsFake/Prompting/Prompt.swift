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

#if compiler(>=6.4)
  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  /// A structured prompt containing text, structured data, or attachments.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`Prompt`](https://developer.apple.com/documentation/foundationmodels/prompt).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct Prompt: Sendable {
    /// The components that make up the prompt.
    internal var components: [Component]

    /// Creates an empty prompt.
    internal init() {
      self.components = []
    }

    /// Creates a prompt with the given components.
    internal init(components: [Component]) {
      self.components = components
    }
  }

  extension Prompt {
    /// Creates a prompt from a prompt-representable value.
    ///
    /// - Parameter content: A prompt-representable value.
    public init(_ content: some PromptRepresentable) {
      self = content.promptRepresentation
    }

    /// Creates a prompt from a variadic list of components.
    ///
    /// - Parameter components: The components that make up the prompt.
    internal init<each P>(_ components: repeat each P) where repeat each P: PromptRepresentable {
      var result: [Component] = []
      func appendOne(_ item: some PromptRepresentable) {
        if let prompt = item as? Prompt {
          result.append(contentsOf: prompt.components)
        } else {
          result.append(contentsOf: item.promptRepresentation.components)
        }
      }
      repeat appendOne(each components)
      self.components = result
    }
  }

  extension Prompt {
    /// An internal representation of a prompt component.
    internal enum Component: Sendable, Equatable {
      /// A text prompt component.
      case text(Text)

      /// A structured content prompt component.
      case structure(Structure)

      /// An attachment prompt component.
      case attachment(Attachment)
    }

    /// A text value in a prompt.
    internal struct Text: Sendable, Equatable {
      /// The string value of the text component.
      internal var value: String

      /// Creates a text component.
      internal init(_ value: String) {
        self.value = value
      }
    }

    /// A structured value in a prompt.
    internal struct Structure: Sendable, Equatable {
      /// The schema name describing the structured type.
      internal var schemaName: String

      /// The structured content of the component.
      internal var content: GeneratedContent
    }

    /// An attachment in a prompt.
    internal struct Attachment: Sendable, Equatable {
      /// The attachment content.
      internal var content: Content

      /// An optional label identifying the attachment.
      internal var label: String?

      /// Creates an attachment component.
      internal init(content: Content, label: String? = nil) {
        self.content = content
        self.label = label
      }

      /// The content of an attachment in a prompt.
      internal enum Content: Sendable, Equatable {
        /// An image attachment content.
        case image(ImageAttachmentContent)

        #if compiler(>=6.4.2)
          /// A binary data attachment content.
          case data(Transcript.DataAttachment)
        #endif  // compiler(>=6.4.2)
      }
    }

    /// Converts prompt components into transcript segments.
    internal var segments: [Transcript.Segment] {
      components.compactMap { component in
        switch component {
        case .text(let t):
          return .text(Transcript.TextSegment(content: t.value))
        case .structure(let s):
          return .structure(
            Transcript.StructuredSegment(
              schemaName: s.schemaName,
              content: s.content
            )
          )
        case .attachment(let a):
          switch a.content {
          case .image(let img):
            let imageAttachment = img.transcriptAttachment
            return .attachment(
              Transcript.AttachmentSegment(
                content: .image(imageAttachment),
                label: a.label
              )
            )
          #if compiler(>=6.4.2)
            case .data(let dataAttachment):
              return .attachment(
                Transcript.AttachmentSegment(
                  content: .data(dataAttachment),
                  label: a.label
                )
              )
          #endif  // compiler(>=6.4.2)
          }
        }
      }
    }
  }

  /// A type that can be converted into a prompt for a language model.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`PromptRepresentable`](https://developer.apple.com/documentation/foundationmodels/promptrepresentable).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public protocol PromptRepresentable {
    /// This value converted to a ``Prompt``.
    @PromptBuilder var promptRepresentation: Prompt { get }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Prompt: PromptRepresentable {
    /// The prompt representation for this instance.
    public var promptRepresentation: Prompt {
      return self
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension String: PromptRepresentable {
    /// A prompt representation wrapping this string as text.
    public var promptRepresentation: Prompt {
      Prompt(components: [.text(Prompt.Text(self))])
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Array: PromptRepresentable where Element: PromptRepresentable {
    /// A prompt representation combining the elements of this array.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var promptRepresentation: Prompt {
      Prompt(components: self.flatMap { $0.promptRepresentation.components })
    }
  }

  /// A result builder that constructs prompts from representable components.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`PromptBuilder`](https://developer.apple.com/documentation/foundationmodels/promptbuilder).
  @resultBuilder
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct PromptBuilder {
  }

  extension PromptBuilder {
    /// Combines multiple prompt-representable components into a prompt.
    ///
    /// - Parameter components: The components to combine.
    /// - Returns: A combined prompt containing all components.
    public static func buildBlock<each P>(
      _ components: repeat each P
    ) -> Prompt where repeat each P: PromptRepresentable {
      Prompt(repeat each components)
    }

    /// Combines an array of prompt-representable components into a prompt.
    ///
    /// - Parameter prompts: The array of components.
    /// - Returns: A combined prompt containing the elements.
    public static func buildArray(_ prompts: [some PromptRepresentable]) -> Prompt {
      Prompt(prompts)
    }

    /// Constructs a prompt from the first conditional branch.
    ///
    /// - Parameter component: The component from the first branch.
    /// - Returns: A prompt wrapping the component.
    public static func buildEither(first component: some PromptRepresentable) -> Prompt {
      Prompt(component)
    }

    /// Constructs a prompt from the second conditional branch.
    ///
    /// - Parameter component: The component from the second branch.
    /// - Returns: A prompt wrapping the component.
    public static func buildEither(second component: some PromptRepresentable) -> Prompt {
      Prompt(component)
    }

    /// Constructs a prompt from an optional prompt value.
    ///
    /// - Parameter component: The optional prompt.
    /// - Returns: The unwrapped prompt, or an empty prompt if `nil`.
    public static func buildOptional(_ component: Prompt?) -> Prompt {
      component ?? Prompt()
    }

    /// Constructs a prompt within an availability check.
    ///
    /// - Parameter prompt: The component available in the current context.
    /// - Returns: A prompt wrapping the component.
    public static func buildLimitedAvailability(_ prompt: some PromptRepresentable) -> Prompt {
      Prompt(prompt)
    }

    /// Builds an expression conforming to ``PromptRepresentable``.
    ///
    /// - Parameter expression: A prompt-representable expression.
    /// - Returns: The unmodified expression.
    @_disfavoredOverload
    public static func buildExpression<P>(_ expression: P) -> P where P: PromptRepresentable {
      expression
    }

    /// Builds a prompt expression.
    ///
    /// - Parameter expression: A prompt expression.
    /// - Returns: The unmodified prompt.
    public static func buildExpression(_ expression: Prompt) -> Prompt {
      expression
    }

    // Disfavored so that, with availability checking disabled inside the fake, the compiler never
    // prefers this overload over the `PromptRepresentable` one.
    /// Rejects expressions that aren't prompts or prompt representable.
    @_disfavoredOverload
    @available(*, unavailable, message: "Only `Prompt` and `PromptRepresentable` are supported.")
    public static func buildExpression<T>(_ expression: T) -> Prompt {
      fatalError()
    }
  }

  extension Prompt {
    /// Creates a prompt by evaluating a closure with a prompt builder.
    ///
    /// - Parameter content: A closure producing a prompt.
    /// - Throws: Rethrows any error thrown by the closure.
    public init(@PromptBuilder _ content: () throws -> Prompt) rethrows {
      self = try content()
    }
  }
#endif  // compiler(>=6.4)
