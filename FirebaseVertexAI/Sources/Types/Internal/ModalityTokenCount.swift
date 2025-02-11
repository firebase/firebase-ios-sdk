// Copyright 2025 Google LLC
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

/// Represents token counting info for a single modality.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct ModalityTokenCount: Sendable {
  /// The modality associated with this token count.
  let modality: ContentModality

  /// The number of tokens counted.
  let tokenCount: Int
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension [ModalityTokenCount] {
  func asModalityTokenDetails() -> [ContentModality: ModalityTokenDetails] {
    var modalityTokenDetails = [ContentModality: ModalityTokenDetails]()
    for modalityTokenCount in self {
      modalityTokenDetails[modalityTokenCount.modality] =
        ModalityTokenDetails(tokenCount: modalityTokenCount.tokenCount)
    }

    return modalityTokenDetails
  }
}

// MARK: - Codable Conformance

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ModalityTokenCount: Decodable {}
