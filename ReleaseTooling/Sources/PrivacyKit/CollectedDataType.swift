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

/// A structure containing metadata about a type of data being collected.
/// https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_data_use_in_privacy_manifests
public struct CollectedDataType: Encodable {
  /// The possible kinds of data types that can be collected.
  public enum Kind: String, CaseIterable, Encodable {
    case name = "NSPrivacyCollectedDataTypeName"
    case emailAddress = "NSPrivacyCollectedDataTypeEmailAddress"
    case phoneNumber = "NSPrivacyCollectedDataTypePhoneNumber"
    case physicalAddress = "NSPrivacyCollectedDataTypePhysicalAddress"
    case otherUserContactInfo = "NSPrivacyCollectedDataTypeOtherUserContactInfo"
    case health = "NSPrivacyCollectedDataTypeHealth"
    case fitness = "NSPrivacyCollectedDataTypeFitness"
    case paymentInfo = "NSPrivacyCollectedDataTypePaymentInfo"
    case creditInfo = "NSPrivacyCollectedDataTypeCreditInfo"
    case otherFinancialInfo = "NSPrivacyCollectedDataTypeOtherFinancialInfo"
    case preciseLocation = "NSPrivacyCollectedDataTypePreciseLocation"
    case coarseLocation = "NSPrivacyCollectedDataTypeCoarseLocation"
    case sensitiveInfo = "NSPrivacyCollectedDataTypeSensitiveInfo"
    case contacts = "NSPrivacyCollectedDataTypeContacts"
    case emailsOrTextMessages = "NSPrivacyCollectedDataTypeEmailsOrTextMessages"
    case photosorVideos = "NSPrivacyCollectedDataTypePhotosorVideos"
    case audioData = "NSPrivacyCollectedDataTypeAudioData"
    case gameplayContent = "NSPrivacyCollectedDataTypeGameplayContent"
    case customerSupport = "NSPrivacyCollectedDataTypeCustomerSupport"
    case otherUserContent = "NSPrivacyCollectedDataTypeOtherUserContent"
    case browsingHistory = "NSPrivacyCollectedDataTypeBrowsingHistory"
    case searchHistory = "NSPrivacyCollectedDataTypeSearchHistory"
    case userID = "NSPrivacyCollectedDataTypeUserID"
    case deviceID = "NSPrivacyCollectedDataTypeDeviceID"
    case purchaseHistory = "NSPrivacyCollectedDataTypePurchaseHistory"
    case productInteraction = "NSPrivacyCollectedDataTypeProductInteraction"
    case advertisingData = "NSPrivacyCollectedDataTypeAdvertisingData"
    case otherUsageData = "NSPrivacyCollectedDataTypeOtherUsageData"
    case crashData = "NSPrivacyCollectedDataTypeCrashData"
    case performanceData = "NSPrivacyCollectedDataTypePerformanceData"
    case otherDiagnosticData = "NSPrivacyCollectedDataTypeOtherDiagnosticData"
    case environmentScanning = "NSPrivacyCollectedDataTypeEnvironmentScanning"
    case hands = "NSPrivacyCollectedDataTypeHands"
    case head = "NSPrivacyCollectedDataTypeHead"
    case otherDataTypes = "NSPrivacyCollectedDataTypeOtherDataTypes"

    public var shortDescription: String {
      switch self {
      case .name: return "name"
      case .emailAddress: return "email address"
      case .phoneNumber: return "phone number"
      case .physicalAddress: return "physical address"
      case .otherUserContactInfo: return "other user contact info"
      case .health: return "health"
      case .fitness: return "fitness"
      case .paymentInfo: return "Payment info"
      case .creditInfo: return "Credit info"
      case .otherFinancialInfo: return "Other financial info"
      case .preciseLocation: return "precise location"
      case .coarseLocation: return "coarse location"
      case .sensitiveInfo: return "sensitive info"
      case .contacts: return "contacts"
      case .emailsOrTextMessages: return "emails or text messages"
      case .photosorVideos: return "photos or videos"
      case .audioData: return "audio data"
      case .gameplayContent: return "gameplay content"
      case .customerSupport: return "customer support"
      case .otherUserContent: return "other user content"
      case .browsingHistory: return "browsing history"
      case .searchHistory: return "search history"
      case .userID: return "user ID"
      case .deviceID: return "device ID"
      case .purchaseHistory: return "purchase history"
      case .productInteraction: return "product interaction"
      case .advertisingData: return "advertising data"
      case .otherUsageData: return "other usage data"
      case .crashData: return "crash data"
      case .performanceData: return "performance data"
      case .otherDiagnosticData: return "other diagnostic data"
      case .environmentScanning: return "environment scanning"
      case .hands: return "hands"
      case .head: return "head"
      case .otherDataTypes: return "other data types"
      }
    }

    var description: String {
      switch self {
      case .name:
        return "Such as first or last name."
      case .emailAddress:
        return "Including but not limited to a hashed email address."
      case .phoneNumber:
        return "Including but not limited to a hashed phone number."
      case .physicalAddress:
        return "Such as home address, physical address, or mailing address."
      case .otherUserContactInfo:
        return "Any other information that can be used to contact the user " +
          "outside the app."
      case .health:
        return "Health and medical data, including but not limited to data " +
          "from the Clinical Health Records API, HealthKit API, " +
          "MovementDisorderAPIs, or health-related human subject research " +
          "or any other user provided health or medical data."
      case .fitness:
        return "Fitness and exercise data, including but not limited to the " +
          "Motion and Fitness API."
      case .paymentInfo:
        return "Such as form of payment, payment card number, or bank " +
          "account number. If your app uses a payment service, the payment " +
          "information is entered outside your app, and you as the " +
          "developer never have access to the payment information, it is " +
          "not collected and does not need to be disclosed."
      case .creditInfo:
        return "Such as credit score."
      case .otherFinancialInfo:
        return "Such as salary, income, assets, debts, or any other " +
          "financial information."
      case .preciseLocation:
        return "Information that describes the location of a user or device " +
          "with the same or greater resolution as a latitude and longitude " +
          "with three or more decimal places."
      case .coarseLocation:
        return "Information that describes the location of a user or device " +
          "with lower resolution than a latitude and longitude with three " +
          "or more decimal places, such as Approximate Location Services."
      case .sensitiveInfo:
        return "Such as racial or ethnic data, sexual orientation, " +
          "pregnancy or childbirth information, disability, religious " +
          "or philosophical beliefs, trade union membership, political " +
          "opinion, genetic information, or biometric data."
      case .contacts:
        return "Such as a list of contacts in the user’s phone, address " +
          "book, or social graph."
      case .emailsOrTextMessages:
        return "Including subject line, sender, recipients, and contents of " +
          "the email or message."
      case .photosorVideos:
        return "The user’s photos or videos."
      case .audioData:
        return "The user’s voice or sound recordings."
      case .gameplayContent:
        return "Such as saved games, multiplayer matching or gameplay " +
          "logic, or user-generated content in-game."
      case .customerSupport:
        return "Data generated by the user during a customer support request."
      case .otherUserContent:
        return "Any other user-generated content."
      case .browsingHistory:
        return "Information about content the user has viewed that is not " +
          "part of the app, such as websites."
      case .searchHistory:
        return "Information about searches performed in the app."
      case .userID:
        return "Such as screen name, handle, account ID, assigned user ID, " +
          "customer number, or other user- or account-level ID that can " +
          "be used to identify a particular user or account."
      case .deviceID:
        return "Such as the device’s advertising identifier, or other " +
          "device-level ID."
      case .purchaseHistory:
        return "An account’s or individual’s purchases or purchase tendencies."
      case .productInteraction:
        return "Such as app launches, taps, clicks, scrolling information, " +
          "music listening data, video views, saved place in a game, video, " +
          "or song, or other information about how the user interacts with " +
          "the app."
      case .advertisingData:
        return "Such as information about the advertisements the user has seen."
      case .otherUsageData:
        return "Any other data about user activity in the app."
      case .crashData:
        return "Such as crash logs."
      case .performanceData:
        return "Such as launch time, hang rate, or energy use."
      case .otherDiagnosticData:
        return "Any other data collected for the purposes of measuring " +
          "technical diagnostics related to the app."
      case .environmentScanning:
        return "Such as mesh, planes, scene classification, and/or image " +
          "detection of the user’s surroundings."
      case .hands:
        return "The user’s hand structure and hand movements."
      case .head:
        return "The user’s head movements."
      case .otherDataTypes:
        return "Any other data types not mentioned."
      }
    }
  }

  /// The purposes for which the data type may be collected.
  public enum Purpose: String, CaseIterable, Encodable {
    case thirdPartyAdvertising = "NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising"
    case developerAdvertising = "NSPrivacyCollectedDataTypePurposeDeveloperAdvertising"
    case analytics = "NSPrivacyCollectedDataTypePurposeAnalytics"
    case productPersonalization = "NSPrivacyCollectedDataTypePurposeProductPersonalization"
    case appFunctionality = "NSPrivacyCollectedDataTypePurposeAppFunctionality"
    case other = "NSPrivacyCollectedDataTypePurposeOther"

    public var shortDescription: String {
      switch self {
      case .thirdPartyAdvertising: return "Third-party advertising"
      case .developerAdvertising: return "Developer’s advertising or marketing"
      case .analytics: return "Analytics"
      case .productPersonalization: return "Product personalization"
      case .appFunctionality: return "App functionality"
      case .other: return "Other purposes"
      }
    }

    public var description: String {
      switch self {
      case .thirdPartyAdvertising:
        return "Such as displaying third-party ads in your app, or sharing " +
          "data with entities who display third-party ads."
      case .developerAdvertising:
        return "Such as displaying first-party ads in your app, sending " +
          "marketing communications directly to your users, or sharing data " +
          "with entities who will display your ads."
      case .analytics:
        return "Using data to evaluate user behavior, including to " +
          "understand the effectiveness of existing product features, plan " +
          "new features, or measure audience size or characteristics."
      case .productPersonalization:
        return "Customizing what the user sees, such as a list of " +
          "recommended products, posts, or suggestions."
      case .appFunctionality:
        return "Such as to authenticate the user, enable features, prevent " +
          "fraud, implement security measures, ensure server up-time, " +
          "minimize app crashes, improve scalability and performance, or " +
          "perform customer support."
      case .other:
        return "Any other purposes not listed."
      }
    }
  }

  /// The kind of data being collected.
  public let kind: Kind
  /// The purposes for which this data is being collected.
  public let purposes: [Purpose]
  /// Whether or not this data is linked to the user.
  public let isLinkedToUser: Bool
  /// Whether or not this data is used for tracking.
  public let isUsedToTrackUser: Bool

  /// These coding keys map to the values defined at
  /// https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_data_use_in_privacy_manifests
  private enum CodingKeys: String, CodingKey {
    case kind = "NSPrivacyCollectedDataType"
    case purposes = "NSPrivacyCollectedDataTypePurposes"
    case isLinkedToUser = "NSPrivacyCollectedDataTypeLinked"
    case isUsedToTrackUser = "NSPrivacyCollectedDataTypeTracking"
  }

  public enum BuilderError: Error {
    case missingField
  }

  public class Builder {
    public var kind: Kind?
    /// It is **invalid** for there to be no purposes.
    public var purposes: [Purpose]?
    public var isLinkedToUser: Bool?
    public var isUsedToTrackUser: Bool?

    public init() {}

    public func build() throws -> CollectedDataType {
      guard
        let kind = kind,
        let purposes = purposes, purposes.count > 0,
        let isLinkedToUser = isLinkedToUser,
        let isUsedToTrackUser = isUsedToTrackUser
      else {
        throw BuilderError.missingField
      }

      return CollectedDataType(
        kind: kind,
        purposes: purposes,
        isLinkedToUser: isLinkedToUser,
        isUsedToTrackUser: isUsedToTrackUser
      )
    }
  }
}
