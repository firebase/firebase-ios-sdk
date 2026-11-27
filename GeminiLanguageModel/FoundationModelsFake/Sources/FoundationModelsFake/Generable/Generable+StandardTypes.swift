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
    public import FoundationEssentials
  #else
    public import Foundation
  #endif

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Bool: Generable {
    /// The generation schema representing Boolean values.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public static var generationSchema: GenerationSchema {
      GenerationSchema._boolean
    }

    /// Creates a Boolean value from generated content.
    ///
    /// - Parameter content: The generated content to convert.
    /// - Throws: An error if the content is not a Boolean value.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public init(_ content: GeneratedContent) throws {
      guard case .bool(let value) = content.node.storage else {
        throw content.conversionError("Bool")
      }
      self = value
    }

    /// The generated content representation of this Boolean value.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var generatedContent: GeneratedContent {
      GeneratedContent(node: ContentNode(.bool(self)), id: nil)
    }

    /// The prompt representation of this Boolean value.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var promptRepresentation: Prompt {
      Prompt(description)
    }

    /// The instructions representation of this Boolean value.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var instructionsRepresentation: Instructions {
      Instructions(description)
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension String: Generable {
    /// The generation schema representing string values.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public static var generationSchema: GenerationSchema {
      GenerationSchema._string
    }

    /// Creates a string from generated content.
    ///
    /// - Parameter content: The generated content to convert.
    /// - Throws: An error if the content is not a string.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public init(_ content: GeneratedContent) throws {
      guard case .string(let value) = content.node.storage else {
        throw content.conversionError("String")
      }
      self = value
    }

    /// The generated content representation of this string.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var generatedContent: GeneratedContent {
      GeneratedContent(node: ContentNode(.string(self)), id: nil)
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Int: Generable {
    /// The generation schema representing integer values.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public static var generationSchema: GenerationSchema {
      GenerationSchema._integer
    }

    /// Creates an integer from generated content.
    ///
    /// - Parameter content: The generated content to convert.
    /// - Throws: An error if the content is not an integer.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public init(_ content: GeneratedContent) throws {
      // Converting through `Double` means a string reports that a `Double` was expected.
      guard let value = Int(exactly: try Double(content)) else {
        throw content.conversionError("an Int")
      }
      self = value
    }

    /// The generated content representation of this integer.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var generatedContent: GeneratedContent {
      GeneratedContent(node: ContentNode(.number(Double(self))), id: nil)
    }

    /// The prompt representation of this integer.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var promptRepresentation: Prompt {
      Prompt(description)
    }

    /// The instructions representation of this integer.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var instructionsRepresentation: Instructions {
      Instructions(description)
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Float: Generable {
    /// The generation schema representing single-precision floating-point values.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public static var generationSchema: GenerationSchema {
      GenerationSchema._double
    }

    /// Creates a single-precision floating-point value from generated content.
    ///
    /// - Parameter content: The generated content to convert.
    /// - Throws: An error if the content cannot be converted to a floating-point value.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public init(_ content: GeneratedContent) throws {
      // Out-of-range values become infinity rather than throwing, like Apple.
      self = Float(try Double(content))
    }

    /// The generated content representation of this single-precision floating-point value.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var generatedContent: GeneratedContent {
      GeneratedContent(node: ContentNode(.number(Double(self))), id: nil)
    }

    /// The prompt representation of this single-precision floating-point value.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var promptRepresentation: Prompt {
      Prompt(description)
    }

    /// The instructions representation of this single-precision floating-point value.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var instructionsRepresentation: Instructions {
      Instructions(description)
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Double: Generable {
    /// The generation schema representing double-precision floating-point values.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public static var generationSchema: GenerationSchema {
      GenerationSchema._double
    }

    /// Creates a double-precision floating-point value from generated content.
    ///
    /// - Parameter content: The generated content to convert.
    /// - Throws: An error if the content is not a floating-point value.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public init(_ content: GeneratedContent) throws {
      guard case .number(let value) = content.node.storage else {
        throw content.conversionError("Double")
      }
      self = value
    }

    /// The generated content representation of this double-precision floating-point value.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var generatedContent: GeneratedContent {
      GeneratedContent(node: ContentNode(.number(self)), id: nil)
    }

    /// The prompt representation of this double-precision floating-point value.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var promptRepresentation: Prompt {
      Prompt(description)
    }

    /// The instructions representation of this double-precision floating-point value.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var instructionsRepresentation: Instructions {
      Instructions(description)
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Decimal: Generable {
    /// The generation schema representing decimal values.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public static var generationSchema: GenerationSchema {
      GenerationSchema._double
    }

    /// Creates a decimal value from generated content.
    ///
    /// - Parameter content: The generated content to convert.
    /// - Throws: An error if the content is not a number.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public init(_ content: GeneratedContent) throws {
      // The stored double converts with `Decimal(_: Double)`, matching Apple's results: `0.1`
      // stays `0.1`, `123.456` becomes `123.45599999999997952`, and `1.2345678901234567e19`
      // becomes `12345678901234567168`. swift-foundation provides the same initializer on Linux.
      self = Decimal(try Double(content))
    }

    /// The generated content representation of this decimal value.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var generatedContent: GeneratedContent {
      GeneratedContent(node: ContentNode(.number(doubleValueForGeneratedContent)), id: nil)
    }

    /// The prompt representation of this decimal value.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var promptRepresentation: Prompt {
      Prompt(description)
    }

    /// The instructions representation of this decimal value.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var instructionsRepresentation: Instructions {
      Instructions(description)
    }

    /// This decimal converted to the `Double` that generated content stores.
    ///
    /// This reproduces `NSDecimalNumber.doubleValue` on every platform: the mantissa is accumulated
    /// in 16-bit words, then scaled by repeated multiplication or division by 10. It matched
    /// `NSDecimalNumber` bit for bit on 20,000 random decimals on macOS, including results such
    /// as `0.0000001` → `1.0000000000000002e-07`.
    private var doubleValueForGeneratedContent: Double {
      if isNaN {
        return .nan
      }
      // `significand` holds the mantissa as an integer; swift-foundation keeps the stored mantissa
      // words internal on Linux, so rebuild the 16-bit words from its decimal digits.
      var digits = significand.description.utf8.compactMap { byte -> UInt32? in
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
          ? UInt32(byte - UInt8(ascii: "0")) : nil
      }
      var words: [UInt32] = []
      while digits.contains(where: { $0 != 0 }) {
        var remainder: UInt32 = 0
        var quotient: [UInt32] = []
        for digit in digits {
          let current = remainder * 10 + digit
          quotient.append(current / 65536)
          remainder = current % 65536
        }
        words.append(remainder)
        digits = Array(quotient.drop { $0 == 0 })
      }
      var value = 0.0
      for word in words.reversed() {
        value = value * 65536 + Double(word)
      }
      if exponent < 0 {
        for _ in exponent..<0 {
          value /= 10
        }
      } else {
        for _ in 0..<exponent {
          value *= 10
        }
      }
      return sign == .minus ? -value : value
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Array: Generable where Element: Generable {
    /// The partially generated representation of an array.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public typealias PartiallyGenerated = [Element.PartiallyGenerated]

    /// The generation schema representing arrays of generable elements.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public static var generationSchema: GenerationSchema {
      GenerationSchema._array(of: Element.generationSchema)
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Array: ConvertibleToGeneratedContent where Element: ConvertibleToGeneratedContent {
    /// The generated content representation of this array.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var generatedContent: GeneratedContent {
      GeneratedContent(node: .array(map { $0.generatedContent.node }), id: nil)
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Array: ConvertibleFromGeneratedContent where Element: ConvertibleFromGeneratedContent {
    /// Creates an array from generated content.
    ///
    /// - Parameter content: The generated content to convert.
    /// - Throws: An error if the content is not an array or if an element cannot be converted.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public init(_ content: GeneratedContent) throws {
      guard case .array(let elements) = content.node.storage else {
        throw content.conversionError("an array")
      }
      self = try elements.map { try Element(GeneratedContent(node: $0, id: content.id)) }
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Never: Generable {
    /// The generation schema representing `Never`.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public static var generationSchema: GenerationSchema {
      GenerationSchema._null
    }

    /// Throws an error because `Never` cannot be initialized.
    ///
    /// - Parameter content: The generated content to convert.
    /// - Throws: An error indicating `Never` cannot be converted from generated content.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public init(_ content: GeneratedContent) throws {
      throw content.conversionError("Never")
    }

    /// Uninhabited generated content for `Never`.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var generatedContent: GeneratedContent {
      switch self {}
    }
  }
#endif  // compiler(>=6.4)
