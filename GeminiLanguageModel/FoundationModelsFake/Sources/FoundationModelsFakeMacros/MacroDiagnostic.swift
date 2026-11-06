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

import SwiftDiagnostics

/// The diagnostics emitted by the `@Generable` and `@Guide` macros.
enum MacroDiagnostic: DiagnosticMessage {
  /// `@Generable` is attached to something other than a struct or enum.
  case generableRequiresStructOrEnum

  /// `@Generable` is attached to a type that already declares a `Generable` conformance.
  case alreadyConformsToGenerable

  /// `@Generable` is attached to an enum without cases.
  case enumWithoutCases

  /// A stored property is declared with a tuple pattern, such as `var (a, b): (Int, Int)`.
  case tuplePatternUnsupported

  /// A stored property has no type annotation, so it can't be part of the schema.
  case missingTypeAnnotation(propertyName: String)

  /// An associated value is labeled `type`, which collides with the enum discriminator.
  case associatedValueNamedType(caseName: String)

  /// Two associated values of a case map to the same property name, such as an unlabeled value
  /// (`value`) and a value labeled `value`.
  case duplicateAssociatedValueName(caseName: String, propertyName: String)

  /// Two cases map to the same `Discriminated*` helper type, such as `a` and `A`.
  case duplicateDiscriminatedTypeName(caseName: String, otherCaseName: String, typeName: String)

  /// `@Guide` is attached to something other than a stored instance property.
  case guideRequiresStoredProperty

  /// The human-readable diagnostic text.
  var message: String {
    switch self {
    case .generableRequiresStructOrEnum:
      return "'@Generable' can only be used on structs and enums."
    case .alreadyConformsToGenerable:
      return
        "Type already conforms to 'Generable'. Remove the '@Generable' macro or delete the "
        + "existing conformance."
    case .enumWithoutCases:
      return "Generable enums must have at least one case."
    case .tuplePatternUnsupported:
      return
        "'@Generable' doesn't support properties declared with a tuple pattern; declare each "
        + "property separately."
    case .missingTypeAnnotation(let propertyName):
      return
        "Property '\(propertyName)' has no type annotation, so '@Generable' excludes it from the "
        + "generation schema; add an explicit type to include it."
    case .associatedValueNamedType(let caseName):
      return
        "The associated value label 'type' in case '\(caseName)' conflicts with the 'type' "
        + "discriminator that '@Generable' generates; rename the label."
    case .duplicateAssociatedValueName(let caseName, let propertyName):
      return
        "Associated values of case '\(caseName)' both map to the property '\(propertyName)'; "
        + "give them distinct labels."
    case .duplicateDiscriminatedTypeName(let caseName, let otherCaseName, let typeName):
      return
        "Cases '\(otherCaseName)' and '\(caseName)' both map to the helper type '\(typeName)'; "
        + "rename one of them."
    case .guideRequiresStoredProperty:
      return "'@Guide' can only be used with a stored property."
    }
  }

  /// A stable identifier for the diagnostic.
  var diagnosticID: MessageID {
    let id: String
    switch self {
    case .generableRequiresStructOrEnum: id = "generableRequiresStructOrEnum"
    case .alreadyConformsToGenerable: id = "alreadyConformsToGenerable"
    case .enumWithoutCases: id = "enumWithoutCases"
    case .tuplePatternUnsupported: id = "tuplePatternUnsupported"
    case .missingTypeAnnotation: id = "missingTypeAnnotation"
    case .associatedValueNamedType: id = "associatedValueNamedType"
    case .duplicateAssociatedValueName: id = "duplicateAssociatedValueName"
    case .duplicateDiscriminatedTypeName: id = "duplicateDiscriminatedTypeName"
    case .guideRequiresStoredProperty: id = "guideRequiresStoredProperty"
    }
    return MessageID(domain: "FoundationModelsFakeMacros", id: id)
  }

  /// The severity of the diagnostic.
  var severity: DiagnosticSeverity {
    switch self {
    case .missingTypeAnnotation: return .warning
    default: return .error
    }
  }
}
