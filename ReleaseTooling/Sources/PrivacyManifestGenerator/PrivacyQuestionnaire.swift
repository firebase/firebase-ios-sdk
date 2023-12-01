// Copyright 2023 Google LLC
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

import Foundation
import PrivacyKit
import Utils

extension Questionnaire {
  /// Creates a questionnaire that, when complete, can be used to generate a Privacy Manifest.
  ///
  /// The questionnaire is composed of four sections, where each section maps to a field of
  /// the  ``PrivacyKit.PrivacyManifest`` structure. See that structure's docs for more details.
  ///
  /// - Parameters:
  ///   - xcframework: The xcframework to generate the Privacy Manifest for.
  ///   - builder: The Privacy Manifest builder to mutate in each question's answer handler closure.
  /// - Returns: A questionnaire that can be used to generate a Privacy Manifest.
  static func makePrivacyQuestionnaire(for xcframework: URL,
                                       with builder: PrivacyManifest.Builder) -> Self {
    let trackingSection = Questionnaire.Section(
      questions: [
        Questionnaire.Question(
          question: """
          Does the SDK use data for tracking as defined under the App Tracking Transparency framework?

          - Refer to the documentation at https://developer.apple.com/app-store/user-privacy-and-data-use/

          """,
          answerHandler: {
            guard case let .bool(answer) = $0 else {
              throw QuestionnaireError.invalidAnswer
            }

            builder.usesDataForTracking = answer
          }
        ),
        Questionnaire.Question(
          question: """
          What internet domains does the SDK connect to that engage in tracking?

          - Refer to the documentation at https://developer.apple.com/app-store/app-privacy-details/#user-tracking

          """,
          isSkippable: true,
          answerHandler: {
            guard case let .string(trackingDomainsString) = $0 else {
              throw QuestionnaireError.invalidAnswer
            }

            let trackingDomains = trackingDomainsString.components(separatedBy: .whitespaces)

            if builder.usesDataForTracking!, trackingDomains.isEmpty {
              throw QuestionnaireError.missingExpectedAnswer(
                message: "SDKs that use data for tracking must provide at " +
                  "least one tracking domain."
              )
            }

            builder.trackingDomains = trackingDomains
          }
        ),
      ]
    )

    let dataCollectionSections = CollectedDataType.Kind.allCases
      .map { dataType in
        Questionnaire.Section(
          questions: [
            Questionnaire.Question(
              question: """
              Does the SDK collect \(dataType.shortDescription.lowercased()) data?

              - Refer to the documentation at https://developer.apple.com/app-store/app-privacy-details/#data-collection

              """,
              answerHandler: {
                guard case let .bool(collectsData) = $0 else {
                  throw QuestionnaireError.invalidAnswer
                }

                guard collectsData else {
                  throw QuestionnaireError.endOfQuestionnaireSection
                }

                let collectedDataBuilder = CollectedDataType.Builder()
                collectedDataBuilder.kind = dataType
                builder.collectedDataTypes.append(collectedDataBuilder)
              }
            ),
            Questionnaire.Question(
              question: "Does the SDK link this type of data to the user’s identity?",
              answerHandler: {
                guard case let .bool(isLinkedToUser) = $0 else {
                  throw QuestionnaireError.invalidAnswer
                }

                builder.collectedDataTypes[builder.collectedDataTypes.endIndex - 1]
                  .isLinkedToUser = isLinkedToUser
              }
            ),
            Questionnaire.Question(
              question: "Does the SDK use this type of data to track?",
              answerHandler: {
                guard case let .bool(isUsedToTrackUser) = $0 else {
                  throw QuestionnaireError.invalidAnswer
                }
                builder.collectedDataTypes[builder.collectedDataTypes.endIndex - 1]
                  .isUsedToTrackUser = isUsedToTrackUser
              }
            ),
            Questionnaire.Question(
              question: CollectedDataType.Purpose.allCases
                .reduce(into: """
                Why does the SDK collect this data?

                  Example:
                    For an SDK that collects the data for analytics and app functionality, enter:

                      NSPrivacyCollectedDataTypePurposeAnalytics NSPrivacyCollectedDataTypePurposeAppFunctionality

                  Options:

                """) { partialResult, purpose in
                  partialResult.append(
                    """
                        \(purpose.shortDescription) (\(purpose.rawValue))
                          - \(purpose.description)


                    """
                  )
                },
              answerHandler: {
                guard case let .string(collectionPurposes) = $0 else {
                  throw QuestionnaireError.invalidAnswer
                }

                let transformedCollectionPurposes = try collectionPurposes
                  .components(separatedBy: CharacterSet.whitespaces)
                  .filter { !$0.isEmpty }
                  .map { rawPurpose in
                    if let purpose = CollectedDataType.Purpose(rawValue: rawPurpose) {
                      purpose
                    } else {
                      throw QuestionnaireError.invalidAnswer
                    }
                  }

                builder.collectedDataTypes[builder.collectedDataTypes.endIndex - 1]
                  .purposes = Array(Set(transformedCollectionPurposes))
              }
            ),
          ]
        )
      }

    // TODO(ncooke3): Wrap next few lines in proper error and document that
    // platform specific privacy manifests are not really supported in this CLI.
    let platformDirectories = try! FileManager.default.contentsOfDirectory(
      at: xcframework,
      includingPropertiesForKeys: [.isDirectoryKey]
    )
    let platformDirectory = platformDirectories.first!
    let frameworkName = (xcframework.lastPathComponent as NSString).deletingPathExtension
    let staticLibrary = platformDirectory.appendingPathComponents([
      "\(frameworkName).framework",
      frameworkName,
    ])

    let accessedAPISection = Questionnaire.Section(
      questions: AccessedAPIType.Category.allCases
        .compactMap { category in
          let searchString = "'\(category.associatedSymbols.joined(separator: #"\|"#))'"

          let result = Shell.executeCommandFromScript(
            "nm \(staticLibrary.path) | grep \(searchString)",
            outputToConsole: false
          )

          guard case let .success(output) = result else {
            // The static library contains no symbols in the restricted API category.
            return nil
          }

          let associatedSymbolsList = category.associatedSymbols.enumerated()
            .reduce("") { partialResult, enumeration in
              partialResult + "\n" + "\(enumeration.offset + 1). \(enumeration.element)"
            }

          let optionsList = category.possibleReasons.reduce("""
          Options:
              skip
                - If you've verified the symbols are unrelated, enter 'skip' to move onto the next category.

          """) { partialResult, reason in
            partialResult + """
                \(reason.rawValue)
                  - \(reason.description)

            """
          }

          return Questionnaire.Question(
            question: """
            Symbols have been detected that may belong to the
              \(category.description) API category:

            ```
            \(output)
            ```

            If the above output contains symbols from the below list
            of symbols, then a corresponding reason should be provided
            (see `Options` below). Else, enter 'skip'.

            \(associatedSymbolsList)

            \(optionsList)

            Example:
              For an SDK that uses File Timestamp APIs for reasons DDA9.1
              and C617.1, enter:

                DDA9.1 C617.1

            Important:
              The APIs are not allowed to be used for reasons other
              than the ones listed in the above section.
            """,
            isSkippable: true
          ) {
            guard case let .string(reasons) = $0 else {
              throw QuestionnaireError.invalidAnswer
            }

            let transformedReasons = try reasons
              .components(separatedBy: CharacterSet.whitespaces)
              .filter { !$0.isEmpty }
              .map { rawReason in
                if let reason = AccessedAPIType.Reason(rawValue: rawReason) {
                  reason
                } else {
                  throw QuestionnaireError.invalidAnswer
                }
              }
            builder.accessedAPITypes.append(AccessedAPIType(
              type: category,
              reasons: transformedReasons
            ))
          }
        }
    )

    return Questionnaire(
      sections: [trackingSection] + dataCollectionSections + [accessedAPISection]
    )
  }
}
