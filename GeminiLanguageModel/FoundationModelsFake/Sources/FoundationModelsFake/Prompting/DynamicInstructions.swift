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

  // MARK: - DynamicInstructions

  /// A protocol for composing dynamic language model instructions and tools.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`DynamicInstructions`](https://developer.apple.com/documentation/foundationmodels/dynamicinstructions).
  @_typeEraser(AnyDynamicInstructions)
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public protocol DynamicInstructions {
    /// The type of dynamic instructions representing the body of this instance.
    associatedtype Body: DynamicInstructions

    /// The content and behavior of the dynamic instructions.
    @DynamicInstructionsBuilder var body: Self.Body { get }
  }

  extension DynamicInstructions {
    /// An alias for creating dynamic instructions from collections.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public typealias ForEach = DynamicInstructionsForEach

    /// An alias for session properties bound to dynamic instructions.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public typealias SessionProperty<Value> = LanguageModelSession.SessionProperty<Value>
  }

  // MARK: - Standard Conformances

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Never: DynamicInstructions {
    /// The type of dynamic instructions representing the body of this instance.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public typealias Body = Never

    /// The content and behavior of the dynamic instructions.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var body: Never {
      fatalError("Never.body should not be called.")
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Optional: DynamicInstructions where Wrapped: DynamicInstructions {
    /// The type of dynamic instructions representing the body of this instance.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public typealias Body = Never

    /// The content and behavior of the dynamic instructions.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var body: Never {
      fatalError("Optional.body should not be called.")
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Instructions: DynamicInstructions {
    /// The type of dynamic instructions representing the body of this instance.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public typealias Body = Never

    /// The content and behavior of the dynamic instructions.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var body: Never {
      fatalError("Instructions.body should not be called.")
    }
  }

  // MARK: - EmptyDynamicInstructions

  /// An empty dynamic instructions value that produces no content or tools.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`EmptyDynamicInstructions`](https://developer.apple.com/documentation/foundationmodels/emptydynamicinstructions).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct EmptyDynamicInstructions: DynamicInstructions, Sendable {
    /// The type of dynamic instructions representing the body of this instance.
    public typealias Body = Never

    /// Creates an empty dynamic instructions value.
    public init() {}

    /// The content and behavior of the dynamic instructions.
    public var body: Never {
      fatalError("EmptyDynamicInstructions.body should not be called.")
    }
  }

  // MARK: - AnyDynamicInstructions

  /// A type-erased wrapper for dynamic instructions values.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`AnyDynamicInstructions`](https://developer.apple.com/documentation/foundationmodels/anydynamicinstructions).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct AnyDynamicInstructions: DynamicInstructions {
    /// The type of dynamic instructions representing the body of this instance.
    public typealias Body = Never

    /// The underlying dynamic instructions value wrapped by this instance.
    internal let storage: any DynamicInstructions

    /// Creates a type-erased dynamic instructions value wrapping any dynamic instructions instance.
    ///
    /// - Parameter dynamicInstructions: The dynamic instructions value to erase.
    public init(_ dynamicInstructions: any DynamicInstructions) {
      if let existing = dynamicInstructions as? AnyDynamicInstructions {
        self.storage = existing.storage
      } else {
        self.storage = dynamicInstructions
      }
    }

    /// Creates a type-erased dynamic instructions value by erasing dynamic instructions.
    ///
    /// - Parameter dynamicInstructions: The dynamic instructions value to erase.
    public init(erasing dynamicInstructions: some DynamicInstructions) {
      self.init(dynamicInstructions)
    }

    /// Creates a type-erased dynamic instructions value from instructions-representable content.
    ///
    /// This isn't part of Apple's API; the fake's result builders use it.
    ///
    /// - Parameter instructions: The instructions-representable value to wrap.
    @_disfavoredOverload
    internal init(_ instructions: some InstructionsRepresentable) {
      self.storage = instructions.instructionsRepresentation
    }

    /// The content and behavior of the dynamic instructions.
    public var body: Never {
      fatalError("AnyDynamicInstructions.body should not be called.")
    }
  }
#endif  // compiler(>=6.4)
