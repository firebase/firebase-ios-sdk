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

public enum FirebaseAppNames {
  /// The name, or a substring of the name, of Firebase apps where App Check is not configured.
  public static let appCheckNotConfigured = "app-check-not-configured"

  /// The name of a Firebase app with no billing account (i.e., the "Spark" plan).
  public static let spark = "spark"
}

public enum ModelNames {
  public static let gemini2Flash = "gemini-2.0-flash-001"
  public static let gemini2FlashLite = "gemini-2.0-flash-lite-001"
  public static let gemini2FlashPreviewImageGeneration = "gemini-2.0-flash-preview-image-generation"
  public static let gemini2FlashLive = "gemini-2.0-flash-live-001"
  public static let gemini2FlashLivePreview = "gemini-2.0-flash-live-preview-04-09"
  public static let gemini2_5_FlashImagePreview = "gemini-2.5-flash-image-preview"
  public static let gemini2_5_Flash = "gemini-2.5-flash"
  public static let gemini2_5_FlashLite = "gemini-2.5-flash-lite"
  public static let gemini2_5_FlashLivePreview = "gemini-live-2.5-flash-preview"
  public static let gemini2_5_Pro = "gemini-2.5-pro"
  public static let gemma3_4B = "gemma-3-4b-it"
}
