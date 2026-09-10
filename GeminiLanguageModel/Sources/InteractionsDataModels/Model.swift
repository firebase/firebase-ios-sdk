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

/// The model that will complete your prompt.\n\nSee [models](https://ai.google.dev/gemini-api/docs/models) for additional details.
package enum Model: Codable, Sendable, Equatable, Hashable {

  /// Our first hybrid reasoning model which supports a 1M token context window and has thinking budgets.
  case gemini25Flash

  /// Our state-of-the-art multipurpose model, which excels at coding and complex reasoning tasks.
  case gemini25Pro

  /// Gemma 4 26B A4B IT
  case gemma426bA4bIt

  /// Gemma 4 31B IT
  case gemma431bIt

  /// Latest release of Gemini Flash
  case geminiFlashLatest

  /// Latest release of Gemini Flash-Lite
  case geminiFlashLiteLatest

  /// Latest release of Gemini Pro
  case geminiProLatest

  /// Our smallest and most cost effective model, built for at scale usage.
  case gemini25FlashLite

  /// Our native image generation model, optimized for speed, flexibility, and contextual understanding. Text input and output is priced the same as 2.5 Flash.
  case gemini25FlashImage

  /// Our most intelligent model built for speed, combining frontier intelligence with superior search and grounding.
  case gemini3FlashPreview

  /// Our latest SOTA reasoning model with unprecedented depth and nuance, and powerful multimodal understanding and coding capabilities.
  case gemini31ProPreview

  /// Gemini 3.1 Pro Preview optimized for custom tool usage
  case gemini31ProPreviewCustomtools

  /// Our most cost-efficient model, optimized for high-volume agentic tasks, translation, and simple data processing.
  case gemini31FlashLite

  /// Gemini 3 Pro Image
  case gemini3ProImage

  /// Gemini 3 Pro Image Preview
  case nanoBananaProPreview

  /// Gemini 3.1 Flash Image.
  case gemini31FlashImage

  /// Our most intelligent model for sustained frontier performance in agentic and coding tasks.
  case gemini35Flash

  /// Our most intelligent model for sustained frontier performance in agentic and coding tasks.
  case gemini36Flash

  /// Our most intelligent model for sustained frontier performance in agentic and coding tasks.
  case gemini37Flash

  /// Our low-latency, music generation model optimized for high-fidelity audio clips and precise rhythmic control.
  case lyria3ClipPreview

  /// Our advanced, full-song generative model with deep compositional understanding, optimized for precise structural control and complex transitions across diverse musical styles.
  case lyria3ProPreview

  /// Gemini Robotics-ER 1.6 Preview
  case geminiRoboticsEr16Preview

  /// Gemini Robotics Embodied Reasoning 2 Preview
  case geminiRoboticsEr2Preview

  /// Unrecognized case.
  ///
  /// - Parameter value: The raw string value of the unrecognized enum case.
  case unrecognized(_ value: String)
}

// MARK: - RawRepresentable Conformance

extension Model: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .gemini25Flash: "gemini-2.5-flash"
    case .gemini25Pro: "gemini-2.5-pro"
    case .gemma426bA4bIt: "gemma-4-26b-a4b-it"
    case .gemma431bIt: "gemma-4-31b-it"
    case .geminiFlashLatest: "gemini-flash-latest"
    case .geminiFlashLiteLatest: "gemini-flash-lite-latest"
    case .geminiProLatest: "gemini-pro-latest"
    case .gemini25FlashLite: "gemini-2.5-flash-lite"
    case .gemini25FlashImage: "gemini-2.5-flash-image"
    case .gemini3FlashPreview: "gemini-3-flash-preview"
    case .gemini31ProPreview: "gemini-3.1-pro-preview"
    case .gemini31ProPreviewCustomtools: "gemini-3.1-pro-preview-customtools"
    case .gemini31FlashLite: "gemini-3.1-flash-lite"
    case .gemini3ProImage: "gemini-3-pro-image"
    case .nanoBananaProPreview: "nano-banana-pro-preview"
    case .gemini31FlashImage: "gemini-3.1-flash-image"
    case .gemini35Flash: "gemini-3.5-flash"
    case .gemini36Flash: "gemini-3.6-flash"
    case .gemini37Flash: "gemini-3.7-flash"
    case .lyria3ClipPreview: "lyria-3-clip-preview"
    case .lyria3ProPreview: "lyria-3-pro-preview"
    case .geminiRoboticsEr16Preview: "gemini-robotics-er-1.6-preview"
    case .geminiRoboticsEr2Preview: "gemini-robotics-er-2-preview"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "gemini-2.5-flash": self = .gemini25Flash
    case "gemini-2.5-pro": self = .gemini25Pro
    case "gemma-4-26b-a4b-it": self = .gemma426bA4bIt
    case "gemma-4-31b-it": self = .gemma431bIt
    case "gemini-flash-latest": self = .geminiFlashLatest
    case "gemini-flash-lite-latest": self = .geminiFlashLiteLatest
    case "gemini-pro-latest": self = .geminiProLatest
    case "gemini-2.5-flash-lite": self = .gemini25FlashLite
    case "gemini-2.5-flash-image": self = .gemini25FlashImage
    case "gemini-3-flash-preview": self = .gemini3FlashPreview
    case "gemini-3.1-pro-preview": self = .gemini31ProPreview
    case "gemini-3.1-pro-preview-customtools": self = .gemini31ProPreviewCustomtools
    case "gemini-3.1-flash-lite": self = .gemini31FlashLite
    case "gemini-3-pro-image": self = .gemini3ProImage
    case "nano-banana-pro-preview": self = .nanoBananaProPreview
    case "gemini-3.1-flash-image": self = .gemini31FlashImage
    case "gemini-3.5-flash": self = .gemini35Flash
    case "gemini-3.6-flash": self = .gemini36Flash
    case "gemini-3.7-flash": self = .gemini37Flash
    case "lyria-3-clip-preview": self = .lyria3ClipPreview
    case "lyria-3-pro-preview": self = .lyria3ProPreview
    case "gemini-robotics-er-1.6-preview": self = .geminiRoboticsEr16Preview
    case "gemini-robotics-er-2-preview": self = .geminiRoboticsEr2Preview
    default: self = .unrecognized(rawValue)
    }
  }
}
