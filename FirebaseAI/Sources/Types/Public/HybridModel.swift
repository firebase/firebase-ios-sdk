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
  /// A hybrid model combining a primary, or main, model and a secondary, or fallback, model.
  ///
  /// **Public Preview**: This API is a public preview and may be subject to change.
  public struct HybridModel: LanguageModel {
    let primary: any LanguageModel
    let secondary: any LanguageModel

    /// **[Public Preview]** Creates a ``HybridModel`` for the specified models.
    ///
    /// > Warning: This API is a public preview and may be subject to change.
    ///
    /// - Parameters:
    ///   - primary: The main, or default, model to use.
    ///   - secondary: The backup model to fallback to if the `primary` model is unavailable.
    public init(primary: any LanguageModel, secondary: any LanguageModel) {
      self.primary = primary
      self.secondary = secondary
    }

    // MARK: LanguageModel Conformance

    public var _modelName: String {
      return "hybrid:\(primary._modelName),\(secondary._modelName)"
    }

    public func _startSession(tools: [any ToolRepresentable]?,
                              instructions: String?) throws -> any _ModelSession {
      var primarySession: (any _ModelSession)?
      var primaryError: Error?
      var secondarySession: (any _ModelSession)?
      var secondaryError: Error?

      do {
        primarySession = try primary._startSession(tools: tools, instructions: instructions)
      } catch {
        primaryError = error
      }

      do {
        secondarySession = try secondary._startSession(tools: tools, instructions: instructions)
      } catch {
        secondaryError = error
      }

      if let primarySession, let secondarySession {
        return HybridModelSession(primary: primarySession, secondary: secondarySession)
      } else if let primarySession {
        return primarySession
      } else if let secondarySession {
        return secondarySession
      } else {
        let debugDescription = """
        Failed to start session for model "\(primary._modelName)": \(primaryError.debugDescription);
        Failed to start session for model "\(secondary._modelName)": \
        \(secondaryError.debugDescription)
        """
        let context = GenerativeModelSession.GenerationError.Context(
          debugDescription: debugDescription
        )

        throw GenerativeModelSession.GenerationError.assetsUnavailable(context)
      }
    }
  }
#endif // compiler(>=6.2.3)
