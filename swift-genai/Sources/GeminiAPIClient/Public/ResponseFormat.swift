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

import Foundation
package import InternalGoogleAIDataModels
package import InternalAgentPlatformDataModels

/// Configuration options for the response output format.
public struct ResponseFormat: Codable, Sendable, Equatable, Hashable {
  public var audio: AudioResponseFormat?
  public var image: ImageResponseFormat?
  public var text: TextMimeType?
  /// - Note: Only supported on AgentPlatform backend.
  public var video: VideoResponseFormat?

  public init(
    audio: AudioResponseFormat? = nil,
    image: ImageResponseFormat? = nil,
    text: TextMimeType? = nil,
    video: VideoResponseFormat? = nil
  ) {
    self.audio = audio
    self.image = image
    self.text = text
    self.video = video
  }
}

public struct AudioResponseFormat: Codable, Sendable, Equatable, Hashable {
  public var delivery: AudioDelivery?
  public var mimeType: AudioMimeType?

  public init(delivery: AudioDelivery? = nil, mimeType: AudioMimeType? = nil) {
    self.delivery = delivery
    self.mimeType = mimeType
  }
}

public enum AudioDelivery: Codable, Sendable, Equatable, Hashable {
  case inline
  case unrecognized(_ value: String)
}

public enum AudioMimeType: Codable, Sendable, Equatable, Hashable {
  case mp3
  case oggOpus
  case l16
  case wav
  case alaw
  case mulaw
  case unrecognized(_ value: String)
}

public struct ImageResponseFormat: Codable, Sendable, Equatable, Hashable {
  public var aspectRatio: ImageAspectRatio?
  public var delivery: ImageDelivery?
  public var imageSize: ImageSize?
  public var mimeType: ImageMimeType?

  public init(
    aspectRatio: ImageAspectRatio? = nil,
    delivery: ImageDelivery? = nil,
    imageSize: ImageSize? = nil,
    mimeType: ImageMimeType? = nil
  ) {
    self.aspectRatio = aspectRatio
    self.delivery = delivery
    self.imageSize = imageSize
    self.mimeType = mimeType
  }
}

public enum ImageAspectRatio: Codable, Sendable, Equatable, Hashable {
  case oneByOne
  case twoByThree
  case threeByTwo
  case threeByFour
  case fourByThree
  case fourByFive
  case fiveByFour
  case nineBySixteen
  case sixteenByNine
  case twentyOneByNine
  case oneByEight
  case eightByOne
  case oneByFour
  case fourByOne
  case unrecognized(_ value: String)
}

public enum ImageDelivery: Codable, Sendable, Equatable, Hashable {
  case inline
  case unrecognized(_ value: String)
}

public enum ImageSize: Codable, Sendable, Equatable, Hashable {
  case fiveTwelve
  case oneK
  case twoK
  case fourK
  case unrecognized(_ value: String)
}

public enum ImageMimeType: Codable, Sendable, Equatable, Hashable {
  case jpeg
  case unrecognized(_ value: String)
}

public enum TextMimeType: Codable, Sendable, Equatable, Hashable {
  case plain
  case json
  case unrecognized(_ value: String)
}

public struct VideoResponseFormat: Codable, Sendable, Equatable, Hashable {
  public var aspectRatio: VideoAspectRatio?
  public var delivery: VideoDelivery?

  public init(aspectRatio: VideoAspectRatio? = nil, delivery: VideoDelivery? = nil) {
    self.aspectRatio = aspectRatio
    self.delivery = delivery
  }
}

public enum VideoAspectRatio: Codable, Sendable, Equatable, Hashable {
  case ratio1x1
  case ratio9x16
  case ratio16x9
  case unrecognized(_ value: String)
}

public enum VideoDelivery: Codable, Sendable, Equatable, Hashable {
  case inline
  case unrecognized(_ value: String)
}

// MARK: - GoogleAI Mappings

extension ResponseFormat {
  package func toGoogleAI() -> GoogleAI.ResponseFormatConfig {
    GoogleAI.ResponseFormatConfig(
      audio: audio?.toGoogleAI(),
      image: image?.toGoogleAI(),
      text: text?.toGoogleAI()
    )
  }

  package init(fromGoogleAI format: GoogleAI.ResponseFormatConfig) {
    self.audio = format.audio.map { AudioResponseFormat(fromGoogleAI: $0) }
    self.image = format.image.map { ImageResponseFormat(fromGoogleAI: $0) }
    self.text = format.text.map { TextMimeType(fromGoogleAI: $0) }
    self.video = nil
  }
}

extension AudioResponseFormat {
  package func toGoogleAI() -> GoogleAI.AudioResponseFormat {
    GoogleAI.AudioResponseFormat(delivery: delivery?.toGoogleAI(), mimeType: mimeType?.toGoogleAI())
  }

  package init(fromGoogleAI format: GoogleAI.AudioResponseFormat) {
    self.delivery = format.delivery.map { AudioDelivery(fromGoogleAI: $0) }
    self.mimeType = format.mimeType.map { AudioMimeType(fromGoogleAI: $0) }
  }
}

extension AudioDelivery {
  package func toGoogleAI() -> GoogleAI.AudioResponseFormat.Delivery {
    switch self {
    case .inline: .inline
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI val: GoogleAI.AudioResponseFormat.Delivery) {
    switch val {
    case .inline: self = .inline
    case .uri: self = .unrecognized("URI")
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension AudioMimeType {
  package func toGoogleAI() -> GoogleAI.AudioResponseFormat.MimeType {
    switch self {
    case .mp3: .mp3
    case .oggOpus: .oggOpus
    case .l16: .l16
    case .wav: .wav
    case .alaw: .alaw
    case .mulaw: .mulaw
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI val: GoogleAI.AudioResponseFormat.MimeType) {
    switch val {
    case .mp3: self = .mp3
    case .oggOpus: self = .oggOpus
    case .l16: self = .l16
    case .wav: self = .wav
    case .alaw: self = .alaw
    case .mulaw: self = .mulaw
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension ImageResponseFormat {
  package func toGoogleAI() -> GoogleAI.ImageResponseFormat {
    GoogleAI.ImageResponseFormat(
      aspectRatio: aspectRatio?.toGoogleAI(),
      delivery: delivery?.toGoogleAI(),
      imageSize: imageSize?.toGoogleAI(),
      mimeType: mimeType?.toGoogleAI()
    )
  }

  package init(fromGoogleAI format: GoogleAI.ImageResponseFormat) {
    self.aspectRatio = format.aspectRatio.map { ImageAspectRatio(fromGoogleAI: $0) }
    self.delivery = format.delivery.map { ImageDelivery(fromGoogleAI: $0) }
    self.imageSize = format.imageSize.map { ImageSize(fromGoogleAI: $0) }
    self.mimeType = format.mimeType.map { ImageMimeType(fromGoogleAI: $0) }
  }
}

extension ImageAspectRatio {
  package func toGoogleAI() -> GoogleAI.ImageResponseFormat.AspectRatio {
    switch self {
    case .oneByOne: .oneByOne
    case .twoByThree: .twoByThree
    case .threeByTwo: .threeByTwo
    case .threeByFour: .threeByFour
    case .fourByThree: .fourByThree
    case .fourByFive: .fourByFive
    case .fiveByFour: .fiveByFour
    case .nineBySixteen: .nineBySixteen
    case .sixteenByNine: .sixteenByNine
    case .twentyOneByNine: .twentyOneByNine
    case .oneByEight: .oneByEight
    case .eightByOne: .eightByOne
    case .oneByFour: .oneByFour
    case .fourByOne: .fourByOne
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI val: GoogleAI.ImageResponseFormat.AspectRatio) {
    switch val {
    case .oneByOne: self = .oneByOne
    case .twoByThree: self = .twoByThree
    case .threeByTwo: self = .threeByTwo
    case .threeByFour: self = .threeByFour
    case .fourByThree: self = .fourByThree
    case .fourByFive: self = .fourByFive
    case .fiveByFour: self = .fiveByFour
    case .nineBySixteen: self = .nineBySixteen
    case .sixteenByNine: self = .sixteenByNine
    case .twentyOneByNine: self = .twentyOneByNine
    case .oneByEight: self = .oneByEight
    case .eightByOne: self = .eightByOne
    case .oneByFour: self = .oneByFour
    case .fourByOne: self = .fourByOne
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension ImageDelivery {
  package func toGoogleAI() -> GoogleAI.ImageResponseFormat.Delivery {
    switch self {
    case .inline: .inline
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI val: GoogleAI.ImageResponseFormat.Delivery) {
    switch val {
    case .inline: self = .inline
    case .uri: self = .unrecognized("URI")
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension ImageSize {
  package func toGoogleAI() -> GoogleAI.ImageResponseFormat.ImageSize {
    switch self {
    case .fiveTwelve: .fiveTwelve
    case .oneK: .oneK
    case .twoK: .twoK
    case .fourK: .fourK
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI val: GoogleAI.ImageResponseFormat.ImageSize) {
    switch val {
    case .fiveTwelve: self = .fiveTwelve
    case .oneK: self = .oneK
    case .twoK: self = .twoK
    case .fourK: self = .fourK
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension ImageMimeType {
  package func toGoogleAI() -> GoogleAI.ImageResponseFormat.MimeType {
    switch self {
    case .jpeg: .jpeg
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI val: GoogleAI.ImageResponseFormat.MimeType) {
    switch val {
    case .jpeg: self = .jpeg
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension TextMimeType {
  package func toGoogleAI() -> GoogleAI.TextResponseFormat {
    GoogleAI.TextResponseFormat(mimeType: toGoogleAIMimeType())
  }

  package init(fromGoogleAI format: GoogleAI.TextResponseFormat) {
    switch format.mimeType {
    case .textPlain: self = .plain
    case .applicationJson: self = .json
    case .unrecognized(let val): self = .unrecognized(val)
    case nil: self = .plain
    }
  }

  private func toGoogleAIMimeType() -> GoogleAI.TextResponseFormat.MimeType {
    switch self {
    case .plain: .textPlain
    case .json: .applicationJson
    case .unrecognized(let val): .unrecognized(val)
    }
  }
}

// MARK: - AgentPlatform Mappings

extension ResponseFormat {
  package func toAgentPlatform() -> AgentPlatform.ResponseFormat {
    AgentPlatform.ResponseFormat(
      audio: audio?.toAgentPlatform(),
      image: image?.toAgentPlatform(),
      text: text?.toAgentPlatform(),
      video: video?.toAgentPlatform()
    )
  }

  package init(fromAgentPlatform format: AgentPlatform.ResponseFormat) {
    self.audio = format.audio.map { AudioResponseFormat(fromAgentPlatform: $0) }
    self.image = format.image.map { ImageResponseFormat(fromAgentPlatform: $0) }
    self.text = format.text.map { TextMimeType(fromAgentPlatform: $0) }
    self.video = format.video.map { VideoResponseFormat(fromAgentPlatform: $0) }
  }
}

extension AudioResponseFormat {
  package func toAgentPlatform() -> AgentPlatform.AudioResponseFormat {
    AgentPlatform.AudioResponseFormat(delivery: delivery?.toAgentPlatform(), mimeType: mimeType?.toAgentPlatform())
  }

  package init(fromAgentPlatform format: AgentPlatform.AudioResponseFormat) {
    self.delivery = format.delivery.map { AudioDelivery(fromAgentPlatform: $0) }
    self.mimeType = format.mimeType.map { AudioMimeType(fromAgentPlatform: $0) }
  }
}

extension AudioDelivery {
  package func toAgentPlatform() -> AgentPlatform.AudioResponseFormat.Delivery {
    switch self {
    case .inline: .inline
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform val: AgentPlatform.AudioResponseFormat.Delivery) {
    switch val {
    case .inline: self = .inline
    case .uri: self = .unrecognized("URI")
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension AudioMimeType {
  package func toAgentPlatform() -> AgentPlatform.AudioResponseFormat.MimeType {
    switch self {
    case .mp3: .mp3
    case .oggOpus: .oggOpus
    case .l16: .l16
    case .wav: .wav
    case .alaw: .alaw
    case .mulaw: .mulaw
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform val: AgentPlatform.AudioResponseFormat.MimeType) {
    switch val {
    case .mp3: self = .mp3
    case .oggOpus: self = .oggOpus
    case .l16: self = .l16
    case .wav: self = .wav
    case .alaw: self = .alaw
    case .mulaw: self = .mulaw
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension ImageResponseFormat {
  package func toAgentPlatform() -> AgentPlatform.ImageResponseFormat {
    AgentPlatform.ImageResponseFormat(
      aspectRatio: aspectRatio?.toAgentPlatform(),
      delivery: delivery?.toAgentPlatform(),
      imageSize: imageSize?.toAgentPlatform(),
      mimeType: mimeType?.toAgentPlatform()
    )
  }

  package init(fromAgentPlatform format: AgentPlatform.ImageResponseFormat) {
    self.aspectRatio = format.aspectRatio.map { ImageAspectRatio(fromAgentPlatform: $0) }
    self.delivery = format.delivery.map { ImageDelivery(fromAgentPlatform: $0) }
    self.imageSize = format.imageSize.map { ImageSize(fromAgentPlatform: $0) }
    self.mimeType = format.mimeType.map { ImageMimeType(fromAgentPlatform: $0) }
  }
}

extension ImageAspectRatio {
  package func toAgentPlatform() -> AgentPlatform.ImageResponseFormat.AspectRatio {
    switch self {
    case .oneByOne: .oneByOne
    case .twoByThree: .twoByThree
    case .threeByTwo: .threeByTwo
    case .threeByFour: .threeByFour
    case .fourByThree: .fourByThree
    case .fourByFive: .fourByFive
    case .fiveByFour: .fiveByFour
    case .nineBySixteen: .nineBySixteen
    case .sixteenByNine: .sixteenByNine
    case .twentyOneByNine: .twentyOneByNine
    case .oneByEight: .oneByEight
    case .eightByOne: .eightByOne
    case .oneByFour: .oneByFour
    case .fourByOne: .fourByOne
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform val: AgentPlatform.ImageResponseFormat.AspectRatio) {
    switch val {
    case .oneByOne: self = .oneByOne
    case .twoByThree: self = .twoByThree
    case .threeByTwo: self = .threeByTwo
    case .threeByFour: self = .threeByFour
    case .fourByThree: self = .fourByThree
    case .fourByFive: self = .fourByFive
    case .fiveByFour: self = .fiveByFour
    case .nineBySixteen: self = .nineBySixteen
    case .sixteenByNine: self = .sixteenByNine
    case .twentyOneByNine: self = .twentyOneByNine
    case .oneByEight: self = .oneByEight
    case .eightByOne: self = .eightByOne
    case .oneByFour: self = .oneByFour
    case .fourByOne: self = .fourByOne
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension ImageDelivery {
  package func toAgentPlatform() -> AgentPlatform.ImageResponseFormat.Delivery {
    switch self {
    case .inline: .inline
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform val: AgentPlatform.ImageResponseFormat.Delivery) {
    switch val {
    case .inline: self = .inline
    case .uri: self = .unrecognized("URI")
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension ImageSize {
  package func toAgentPlatform() -> AgentPlatform.ImageResponseFormat.ImageSize {
    switch self {
    case .fiveTwelve: .fiveTwelve
    case .oneK: .oneK
    case .twoK: .twoK
    case .fourK: .fourK
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform val: AgentPlatform.ImageResponseFormat.ImageSize) {
    switch val {
    case .fiveTwelve: self = .fiveTwelve
    case .oneK: self = .oneK
    case .twoK: self = .twoK
    case .fourK: self = .fourK
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension ImageMimeType {
  package func toAgentPlatform() -> AgentPlatform.ImageResponseFormat.MimeType {
    switch self {
    case .jpeg: .jpeg
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform val: AgentPlatform.ImageResponseFormat.MimeType) {
    switch val {
    case .jpeg: self = .jpeg
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension TextMimeType {
  package func toAgentPlatform() -> AgentPlatform.TextResponseFormat {
    AgentPlatform.TextResponseFormat(mimeType: toAgentPlatformMimeType())
  }

  package init(fromAgentPlatform format: AgentPlatform.TextResponseFormat) {
    switch format.mimeType {
    case .textPlain: self = .plain
    case .applicationJson: self = .json
    case .unrecognized(let val): self = .unrecognized(val)
    case nil: self = .plain
    }
  }

  private func toAgentPlatformMimeType() -> AgentPlatform.TextResponseFormat.MimeType {
    switch self {
    case .plain: .textPlain
    case .json: .applicationJson
    case .unrecognized(let val): .unrecognized(val)
    }
  }
}

extension VideoResponseFormat {
  package func toAgentPlatform() -> AgentPlatform.VideoResponseFormat {
    AgentPlatform.VideoResponseFormat(aspectRatio: aspectRatio?.toAgentPlatform(), delivery: delivery?.toAgentPlatform())
  }

  package init(fromAgentPlatform format: AgentPlatform.VideoResponseFormat) {
    self.aspectRatio = format.aspectRatio.map { VideoAspectRatio(fromAgentPlatform: $0) }
    self.delivery = format.delivery.map { VideoDelivery(fromAgentPlatform: $0) }
  }
}

extension VideoAspectRatio {
  package func toAgentPlatform() -> AgentPlatform.VideoResponseFormat.AspectRatio {
    switch self {
    case .ratio1x1: .sixteenByNine
    case .ratio9x16: .nineBySixteen
    case .ratio16x9: .sixteenByNine
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform val: AgentPlatform.VideoResponseFormat.AspectRatio) {
    switch val {
    case .sixteenByNine: self = .ratio16x9
    case .nineBySixteen: self = .ratio9x16
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

extension VideoDelivery {
  package func toAgentPlatform() -> AgentPlatform.VideoResponseFormat.Delivery {
    switch self {
    case .inline: .inline
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform val: AgentPlatform.VideoResponseFormat.Delivery) {
    switch val {
    case .inline: self = .inline
    case .uri: self = .unrecognized("URI")
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}
