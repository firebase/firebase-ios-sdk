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

  /// A structured set of instructions guiding language model behavior.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`Instructions`](https://developer.apple.com/documentation/foundationmodels/instructions).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct Instructions: Sendable {
    /// The components that make up the instructions.
    internal var components: [Component]

    /// Creates empty instructions.
    internal init() {
      self.components = []
    }

    /// Creates instructions with the given components.
    internal init(components: [Component]) {
      self.components = components
    }
  }

  extension Instructions {
    /// Creates instructions from an instructions-representable value.
    ///
    /// - Parameter content: An instructions-representable value.
    public init(_ content: some InstructionsRepresentable) {
      self = content.instructionsRepresentation
    }

    /// Creates instructions from a variadic list of components.
    ///
    /// - Parameter components: The components that make up the instructions.
    internal init<each I>(_ components: repeat each I)
    where repeat each I: InstructionsRepresentable {
      var result: [Component] = []
      func appendOne(_ item: some InstructionsRepresentable) {
        if let instructions = item as? Instructions {
          result.append(contentsOf: instructions.components)
        } else {
          result.append(contentsOf: item.instructionsRepresentation.components)
        }
      }
      repeat appendOne(each components)
      self.components = result
    }
  }

  extension Instructions {
    /// An internal representation of an instructions component.
    internal enum Component: Sendable, Equatable {
      /// A text instructions component.
      case text(Text)

      /// A structured content instructions component.
      case structure(Structure)

      /// An attachment instructions component.
      case attachment(Attachment)
    }

    /// A text value in instructions.
    internal struct Text: Sendable, Equatable {
      /// The string value of the text component.
      internal var value: String

      /// Creates a text component.
      internal init(_ value: String) {
        self.value = value
      }
    }

    /// A structured value in instructions.
    internal struct Structure: Sendable, Equatable {
      /// The schema name describing the structured type.
      internal var schemaName: String

      /// The structured content of the component.
      internal var content: GeneratedContent
    }

    /// An attachment in instructions.
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

      /// The content of an attachment in instructions.
      internal enum Content: Sendable, Equatable {
        /// An image attachment content.
        case image(ImageAttachmentContent)

        #if compiler(>=6.4.2)
          /// A binary data attachment content.
          case data(Transcript.DataAttachment)
        #endif  // compiler(>=6.4.2)
      }
    }

    /// Converts instructions components into transcript segments.
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

  /// A type that can be converted into instructions for a language model.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`InstructionsRepresentable`](https://developer.apple.com/documentation/foundationmodels/instructionsrepresentable).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public protocol InstructionsRepresentable {
    /// This value converted to ``Instructions``.
    @InstructionsBuilder var instructionsRepresentation: Instructions { get }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Instructions: InstructionsRepresentable {
    /// The instructions representation for this instance.
    public var instructionsRepresentation: Instructions {
      return self
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension String: InstructionsRepresentable {
    /// An instructions representation wrapping this string as text.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var instructionsRepresentation: Instructions {
      Instructions(components: [.text(Instructions.Text(self))])
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Array: InstructionsRepresentable where Element: InstructionsRepresentable {
    /// An instructions representation combining the elements of this array.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var instructionsRepresentation: Instructions {
      Instructions(components: self.flatMap { $0.instructionsRepresentation.components })
    }
  }

  /// A result builder that constructs instructions from representable components.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`InstructionsBuilder`](https://developer.apple.com/documentation/foundationmodels/instructionsbuilder).
  @resultBuilder
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct InstructionsBuilder {
  }

  extension InstructionsBuilder {
    /// Combines multiple instructions-representable components into instructions.
    ///
    /// - Parameter components: The components to combine.
    /// - Returns: Combined instructions containing all components.
    public static func buildBlock<each I>(
      _ components: repeat each I
    ) -> Instructions where repeat each I: InstructionsRepresentable {
      Instructions(repeat each components)
    }

    /// Combines an array of instructions-representable components into instructions.
    ///
    /// - Parameter instructions: The array of components.
    /// - Returns: Combined instructions containing the elements.
    public static func buildArray(_ instructions: [some InstructionsRepresentable]) -> Instructions
    {
      Instructions(instructions)
    }

    /// Constructs instructions from the first conditional branch.
    ///
    /// - Parameter component: The component from the first branch.
    /// - Returns: Instructions wrapping the component.
    public static func buildEither(first component: some InstructionsRepresentable) -> Instructions
    {
      Instructions(component)
    }

    /// Constructs instructions from the second conditional branch.
    ///
    /// - Parameter component: The component from the second branch.
    /// - Returns: Instructions wrapping the component.
    public static func buildEither(second component: some InstructionsRepresentable) -> Instructions
    {
      Instructions(component)
    }

    /// Constructs instructions from an optional instructions value.
    ///
    /// - Parameter instructions: The optional instructions.
    /// - Returns: The unwrapped instructions, or empty instructions if `nil`.
    public static func buildOptional(_ instructions: Instructions?) -> Instructions {
      instructions ?? Instructions()
    }

    /// Constructs instructions within an availability check.
    ///
    /// - Parameter instructions: The component available in the current context.
    /// - Returns: Instructions wrapping the component.
    public static func buildLimitedAvailability(
      _ instructions: some InstructionsRepresentable
    ) -> Instructions {
      Instructions(instructions)
    }

    /// Builds an expression conforming to ``InstructionsRepresentable``.
    ///
    /// - Parameter expression: An instructions-representable expression.
    /// - Returns: The unmodified expression.
    @_disfavoredOverload
    public static func buildExpression<I>(_ expression: I) -> I where I: InstructionsRepresentable {
      expression
    }

    /// Builds an instructions expression.
    ///
    /// - Parameter expression: An instructions expression.
    /// - Returns: The unmodified instructions.
    public static func buildExpression(_ expression: Instructions) -> Instructions {
      expression
    }

    // Disfavored so that, with availability checking disabled inside the fake, the compiler never
    // prefers this overload over the `InstructionsRepresentable` one.
    /// Rejects expressions that aren't instructions or instructions representable.
    @_disfavoredOverload
    @available(
      *, unavailable, message: "Only `Instructions` and `InstructionsRepresentable` are supported."
    )
    public static func buildExpression<T>(_ expression: T) -> Instructions {
      fatalError()
    }
  }

  extension Instructions {
    /// Creates instructions by evaluating a closure with an instructions builder.
    ///
    /// - Parameter content: A closure producing instructions.
    /// - Throws: Rethrows any error thrown by the closure.
    public init(@InstructionsBuilder _ content: () throws -> Instructions) rethrows {
      self = try content()
    }
  }
#endif  // compiler(>=6.4)
