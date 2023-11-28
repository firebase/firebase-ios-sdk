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
  public enum Kind: String, Encodable {
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

    var shortDescription: String {
      switch self {
      case .name: "name"
      case .emailAddress: "email address"
      case .phoneNumber: "phone number"
      case .physicalAddress: "physical address"
      case .otherUserContactInfo: "other user contact info"
      case .health: "health"
      case .fitness: "fitness"
      case .paymentInfo: "Payment info"
      case .creditInfo: "Credit info"
      case .otherFinancialInfo: "Other financial info"
      case .preciseLocation: "precise location"
      case .coarseLocation: "coarse location"
      case .sensitiveInfo: "sensitive info"
      case .contacts: "contacts"
      case .emailsOrTextMessages: "emails or text messages"
      case .photosorVideos: "photos or videos"
      case .audioData: "audio data"
      case .gameplayContent: "gameplay content"
      case .customerSupport: "customer support"
      case .otherUserContent: "other user content"
      case .browsingHistory: "browsing history"
      case .searchHistory: "search history"
      case .userID: "user ID"
      case .deviceID: "device ID"
      case .purchaseHistory: "purchase history"
      case .productInteraction: "product interaction"
      case .advertisingData: "advertising data"
      case .otherUsageData: "other usage data"
      case .crashData: "crash data"
      case .performanceData: "performance data"
      case .otherDiagnosticData: "other diagnostic data"
      case .environmentScanning: "environment scanning"
      case .hands: "hands"
      case .head: "head"
      case .otherDataTypes: "other data types"
      }
    }

    var description: String {
      switch self {
      case .name:
        "Such as first or last name."
      case .emailAddress:
        "Including but not limited to a hashed email address."
      case .phoneNumber:
        "Including but not limited to a hashed phone number."
      case .physicalAddress:
        "Such as home address, physical address, or mailing address."
      case .otherUserContactInfo:
        "Any other information that can be used to contact the user outside the app."
      case .health:
        "Health and medical data, including but not limited to data from the Clinical Health Records API, HealthKit API, MovementDisorderAPIs, or health-related human subject research or any other user provided health or medical data."
      case .fitness:
        "Fitness and exercise data, including but not limited to the Motion and Fitness API."
      case .paymentInfo:
        "Such as form of payment, payment card number, or bank account number. If your app uses a payment service, the payment information is entered outside your app, and you as the developer never have access to the payment information, it is not collected and does not need to be disclosed."
      case .creditInfo:
        "Such as credit score."
      case .otherFinancialInfo:
        "Such as salary, income, assets, debts, or any other financial information."
      case .preciseLocation:
        "Information that describes the location of a user or device with the same or greater resolution as a latitude and longitude with three or more decimal places."
      case .coarseLocation:
        "Information that describes the location of a user or device with lower resolution than a latitude and longitude with three or more decimal places, such as Approximate Location Services."
      case .sensitiveInfo:
        "Such as racial or ethnic data, sexual orientation, pregnancy or childbirth information, disability, religious or philosophical beliefs, trade union membership, political opinion, genetic information, or biometric data."
      case .contacts:
        "Such as a list of contacts in the user’s phone, address book, or social graph."
      case .emailsOrTextMessages:
        "Including subject line, sender, recipients, and contents of the email or message."
      case .photosorVideos:
        "The user’s photos or videos."
      case .audioData:
        "The user’s voice or sound recordings."
      case .gameplayContent:
        "Such as saved games, multiplayer matching or gameplay logic, or user-generated content in-game."
      case .customerSupport:
        "Data generated by the user during a customer support request."
      case .otherUserContent:
        "Any other user-generated content."
      case .browsingHistory:
        "Information about content the user has viewed that is not part of the app, such as websites."
      case .searchHistory:
        "Information about searches performed in the app."
      case .userID:
        "Such as screen name, handle, account ID, assigned user ID, customer number, or other user- or account-level ID that can be used to identify a particular user or account."
      case .deviceID:
        "Such as the device’s advertising identifier, or other device-level ID."
      case .purchaseHistory:
        "An account’s or individual’s purchases or purchase tendencies."
      case .productInteraction:
        "Such as app launches, taps, clicks, scrolling information, music listening data, video views, saved place in a game, video, or song, or other information about how the user interacts with the app."
      case .advertisingData:
        "Such as information about the advertisements the user has seen."
      case .otherUsageData:
        "Any other data about user activity in the app."
      case .crashData:
        "Such as crash logs."
      case .performanceData:
        "Such as launch time, hang rate, or energy use."
      case .otherDiagnosticData:
        "Any other data collected for the purposes of measuring technical diagnostics related to the app."
      case .environmentScanning:
        "Such as mesh, planes, scene classification, and/or image detection of the user’s surroundings."
      case .hands:
        "The user’s hand structure and hand movements."
      case .head:
        "The user’s head movements."
      case .otherDataTypes:
        "Any other data types not mentioned."
      }
    }
  }

  /// The purposes for which the data type may be collected.
  public enum Purpose: String, Encodable {
    case thirdPartyAdvertising = "NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising"
    case developerAdvertising = "NSPrivacyCollectedDataTypePurposeDeveloperAdvertising"
    case analytics = "NSPrivacyCollectedDataTypePurposeAnalytics"
    case productPersonalization = "NSPrivacyCollectedDataTypePurposeProductPersonalization"
    case appFunctionality = "NSPrivacyCollectedDataTypePurposeAppFunctionality"
    case other = "NSPrivacyCollectedDataTypePurposeOther"

    var shortDescription: String {
      switch self {
      case .thirdPartyAdvertising:
        "Third-party advertising"
      case .developerAdvertising:
        "Developer’s advertising or marketing"
      case .analytics:
        "Analytics"
      case .productPersonalization:
        "Product personalization"
      case .appFunctionality:
        "App functionality"
      case .other:
        "Other purposes"
      }
    }

    var description: String {
      switch self {
      case .thirdPartyAdvertising:
        "Such as displaying third-party ads in your app, or sharing data with entities who display third-party ads."
      case .developerAdvertising:
        "Such as displaying first-party ads in your app, sending marketing communications directly to your users, or sharing data with entities who will display your ads."
      case .analytics:
        "Using data to evaluate user behavior, including to understand the effectiveness of existing product features, plan new features, or measure audience size or characteristics."
      case .productPersonalization:
        "Customizing what the user sees, such as a list of recommended products, posts, or suggestions."
      case .appFunctionality:
        "Such as to authenticate the user, enable features, prevent fraud, implement security measures, ensure server up-time, minimize app crashes, improve scalability and performance, or perform customer support."
      case .other:
        "Any other purposes not listed."
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
}
