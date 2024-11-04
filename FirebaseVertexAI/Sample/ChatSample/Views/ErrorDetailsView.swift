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

import FirebaseVertexAI
import MarkdownUI
import SwiftUI

private extension HarmCategory {
  /// Returns a description of the `HarmCategory` suitable for displaying in the UI.
  var displayValue: String {
    switch self {
    case .dangerousContent: "Dangerous content"
    case .harassment: "Harassment"
    case .hateSpeech: "Hate speech"
    case .sexuallyExplicit: "Sexually explicit"
    case .civicIntegrity: "Civic integrity"
    default: "Unknown HarmCategory: \(rawValue)"
    }
  }
}

private extension SafetyRating.HarmProbability {
  /// Returns a description of the `HarmProbability` suitable for displaying in the UI.
  var displayValue: String {
    switch self {
    case .high: "High"
    case .low: "Low"
    case .medium: "Medium"
    case .negligible: "Negligible"
    default: "Unknown HarmProbability: \(rawValue)"
    }
  }
}

private struct SubtitleFormRow: View {
  var title: String
  var value: String

  var body: some View {
    VStack(alignment: .leading) {
      Text(title)
        .font(.subheadline)
      Text(value)
    }
  }
}

private struct SubtitleMarkdownFormRow: View {
  var title: String
  var value: String

  var body: some View {
    VStack(alignment: .leading) {
      Text(title)
        .font(.subheadline)
      Markdown(value)
    }
  }
}

private struct SafetyRatingsSection: View {
  var ratings: [SafetyRating]

  var body: some View {
    Section("Safety ratings") {
      List(ratings, id: \.self) { rating in
        HStack {
          Text(rating.category.displayValue).font(.subheadline)
          Spacer()
          Text(rating.probability.displayValue)
        }
      }
    }
  }
}

struct ErrorDetailsView: View {
  var error: Error

  var body: some View {
    NavigationView {
      Form {
        switch error {
        case let GenerateContentError.internalError(underlying: underlyingError):
          Section("Error Type") {
            Text("Internal error")
          }

          Section("Details") {
            SubtitleFormRow(title: "Error description",
                            value: underlyingError.localizedDescription)
          }

        case let GenerateContentError.promptBlocked(response: generateContentResponse):
          Section("Error Type") {
            Text("Your prompt was blocked")
          }

          Section("Details") {
            if let reason = generateContentResponse.promptFeedback?.blockReason {
              SubtitleFormRow(title: "Reason for blocking", value: reason.rawValue)
            }

            if let text = generateContentResponse.text {
              SubtitleMarkdownFormRow(title: "Last chunk for the response", value: text)
            }
          }

          if let ratings = generateContentResponse.candidates.first?.safetyRatings {
            SafetyRatingsSection(ratings: ratings)
          }

        case let GenerateContentError.responseStoppedEarly(
          reason: finishReason,
          response: generateContentResponse
        ):

          Section("Error Type") {
            Text("Response stopped early")
          }

          Section("Details") {
            SubtitleFormRow(title: "Reason for finishing early", value: finishReason.rawValue)

            if let text = generateContentResponse.text {
              SubtitleMarkdownFormRow(title: "Last chunk for the response", value: text)
            }
          }

          if let ratings = generateContentResponse.candidates.first?.safetyRatings {
            SafetyRatingsSection(ratings: ratings)
          }

        default:
          Section("Error Type") {
            Text("Some other error")
          }

          Section("Details") {
            SubtitleFormRow(title: "Error description", value: error.localizedDescription)
          }
        }
      }
      .navigationTitle("Error details")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#Preview("Response Stopped Early") {
  let error = GenerateContentError.responseStoppedEarly(
    reason: .maxTokens,
    response: GenerateContentResponse(candidates: [
      Candidate(content: ModelContent(role: "model", parts:
        """
        A _hypothetical_ model response.
        Cillum ex aliqua amet aliquip labore amet eiusmod consectetur reprehenderit sit commodo.
        """),
      safetyRatings: [
        SafetyRating(
          category: .dangerousContent,
          probability: .medium,
          probabilityScore: 0.8,
          severity: .medium,
          severityScore: 0.9,
          blocked: false
        ),
        SafetyRating(
          category: .harassment,
          probability: .low,
          probabilityScore: 0.5,
          severity: .low,
          severityScore: 0.6,
          blocked: false
        ),
        SafetyRating(
          category: .hateSpeech,
          probability: .low,
          probabilityScore: 0.3,
          severity: .medium,
          severityScore: 0.2,
          blocked: false
        ),
        SafetyRating(
          category: .sexuallyExplicit,
          probability: .low,
          probabilityScore: 0.2,
          severity: .negligible,
          severityScore: 0.5,
          blocked: false
        ),
      ],
      finishReason: FinishReason.maxTokens,
      citationMetadata: nil),
    ])
  )

  return ErrorDetailsView(error: error)
}

#Preview("Prompt Blocked") {
  let error = GenerateContentError.promptBlocked(
    response: GenerateContentResponse(candidates: [
      Candidate(content: ModelContent(role: "model", parts:
        """
        A _hypothetical_ model response.
        Cillum ex aliqua amet aliquip labore amet eiusmod consectetur reprehenderit sit commodo.
        """),
      safetyRatings: [
        SafetyRating(
          category: .dangerousContent,
          probability: .low,
          probabilityScore: 0.8,
          severity: .medium,
          severityScore: 0.9,
          blocked: false
        ),
        SafetyRating(
          category: .harassment,
          probability: .low,
          probabilityScore: 0.5,
          severity: .low,
          severityScore: 0.6,
          blocked: false
        ),
        SafetyRating(
          category: .hateSpeech,
          probability: .low,
          probabilityScore: 0.3,
          severity: .medium,
          severityScore: 0.2,
          blocked: false
        ),
        SafetyRating(
          category: .sexuallyExplicit,
          probability: .low,
          probabilityScore: 0.2,
          severity: .negligible,
          severityScore: 0.5,
          blocked: false
        ),
      ],
      finishReason: FinishReason.other,
      citationMetadata: nil),
    ])
  )

  return ErrorDetailsView(error: error)
}
