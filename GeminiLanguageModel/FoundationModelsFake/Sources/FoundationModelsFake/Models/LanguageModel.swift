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
  #if canImport(UniformTypeIdentifiers)
    #if compiler(>=6.4.2)
      public import UniformTypeIdentifiers
    #else
      import UniformTypeIdentifiers
    #endif
  #endif

  /// A type that defines a language model and its execution capabilities.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`LanguageModel`](https://developer.apple.com/documentation/foundationmodels/languagemodel).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public protocol LanguageModel: Sendable {
    /// The executor type that drives generation for this model.
    associatedtype Executor: LanguageModelExecutor where Self == Self.Executor.Model

    /// The set of capabilities supported by this model.
    var capabilities: LanguageModelCapabilities { get }

    /// The configuration used to initialize the model executor.
    var executorConfiguration: Self.Executor.Configuration { get }

    #if compiler(>=6.4.2)
      /// Returns whether data attachments of the specified uniform type are supported.
      ///
      /// - Parameter type: The uniform type identifier of the attachment.
      /// - Returns: `true` if the attachment type is supported; otherwise, `false`.
      /// - Throws: An error if determining support fails.
      @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
      @available(tvOS, unavailable)
      nonisolated(nonsending) func supportsDataAttachmentType(_ type: UTType) async throws -> Bool
    #endif  // compiler(>=6.4.2)

    #if compiler(>=6.4.2)
      /// Returns whether data entries of the specified uniform type are supported.
      ///
      /// - Parameter type: The uniform type identifier of the data entry.
      /// - Returns: `true` if the data entry type is supported; otherwise, `false`.
      /// - Throws: An error if determining support fails.
      @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
      @available(tvOS, unavailable)
      nonisolated(nonsending) func supportsDataEntryType(_ type: UTType) async throws -> Bool
    #endif  // compiler(>=6.4.2)
  }

  extension LanguageModel {
    #if compiler(>=6.4.2)
      /// Returns whether data attachments of the given type are supported, returning `false`.
      ///
      /// - Parameter type: The uniform type identifier of the attachment.
      /// - Returns: `true` if the attachment type is supported; otherwise, `false`.
      /// - Throws: An error if determining support fails.
      @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
      @available(tvOS, unavailable)
      nonisolated(nonsending) public func supportsDataAttachmentType(
        _ type: UTType
      ) async throws -> Bool {
        false
      }
    #endif  // compiler(>=6.4.2)

    #if compiler(>=6.4.2)
      /// Returns whether data entries of the given type are supported, returning `false`.
      ///
      /// - Parameter type: The uniform type identifier of the data entry.
      /// - Returns: `true` if the data entry type is supported; otherwise, `false`.
      /// - Throws: An error if determining support fails.
      @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
      @available(tvOS, unavailable)
      nonisolated(nonsending) public func supportsDataEntryType(_ type: UTType) async throws -> Bool
      {
        false
      }
    #endif  // compiler(>=6.4.2)
  }
#endif  // compiler(>=6.4)
