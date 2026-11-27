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
  /// Generates conformance to ``Generable`` for a type.
  ///
  /// - Parameter description: An optional description of the generable type.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`Generable`](https://developer.apple.com/documentation/foundationmodels/generable(description:)).
  @attached(extension, conformances: Generable, names: named(init(_:)), named(generatedContent))
  @attached(member, names: arbitrary)
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public macro Generable(description: String? = nil) =
    #externalMacro(module: "FoundationModelsFakeMacros", type: "GenerableMacro")

  /// Generates conformance to ``Generable`` for a type, specifying explicit nil handling.
  ///
  /// - Parameters:
  ///   - description: An optional description of the generable type.
  ///   - representNilExplicitlyInGeneratedContent: Whether `nil` properties are represented
  ///     explicitly.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`Generable`](https://developer.apple.com/documentation/foundationmodels/generable(description:representnilexplicitlyingeneratedcontent:)).
  @attached(extension, conformances: Generable, names: named(init(_:)), named(generatedContent))
  @attached(member, names: arbitrary)
  @available(iOS 26.4, macOS 26.4, visionOS 26.4, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public macro Generable(
    description: String? = nil,
    representNilExplicitlyInGeneratedContent: Bool
  ) = #externalMacro(module: "FoundationModelsFakeMacros", type: "GenerableMacro")

  /// Generates conformance to ``Generable`` for a type with a custom schema name.
  ///
  /// - Parameters:
  ///   - name: The custom name for the schema.
  ///   - description: An optional description of the generable type.
  ///   - representNilExplicitlyInGeneratedContent: Whether `nil` properties are represented
  ///     explicitly.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`Generable`](https://developer.apple.com/documentation/foundationmodels/generable(name:description:representnilexplicitlyingeneratedcontent:)).
  @attached(extension, conformances: Generable, names: named(init(_:)), named(generatedContent))
  @attached(member, names: arbitrary)
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public macro Generable(
    name: String,
    description: String? = nil,
    representNilExplicitlyInGeneratedContent: Bool = false
  ) = #externalMacro(module: "FoundationModelsFakeMacros", type: "GenerableMacro")

  /// Attaches generation guides and an optional description to a generable property.
  ///
  /// - Parameters:
  ///   - description: An optional description of the property.
  ///   - guides: One or more generation guides to apply to the property.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`Guide`](https://developer.apple.com/documentation/foundationmodels/guide(description:_:)).
  @attached(peer)
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public macro Guide<T>(description: String? = nil, _ guides: GenerationGuide<T>...) =
    #externalMacro(module: "FoundationModelsFakeMacros", type: "GuideMacro")
  where T: Generable

  /// Attaches a regular expression pattern guide and an optional description to a string property.
  ///
  /// - Parameters:
  ///   - description: An optional description of the property.
  ///   - guides: A regular expression pattern that the property value must match.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`Guide`](https://developer.apple.com/documentation/foundationmodels/guide(description:_:)).
  @attached(peer)
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public macro Guide<RegexOutput>(description: String? = nil, _ guides: Regex<RegexOutput>) =
    #externalMacro(module: "FoundationModelsFakeMacros", type: "GuideMacro")

  /// Attaches a natural language description to a property of a generable type.
  ///
  /// - Parameter description: A description of the property.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`Guide`](https://developer.apple.com/documentation/foundationmodels/guide(description:)).
  @attached(peer)
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public macro Guide(description: String) =
    #externalMacro(module: "FoundationModelsFakeMacros", type: "GuideMacro")
#endif  // compiler(>=6.4)
