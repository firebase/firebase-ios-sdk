//
// Copyright 2022 Google LLC
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
//

// MARK: This file is used to evaluate the experience of using Analytics APIs in Swift.

import FirebaseAnalytics
import Foundation

final class AnalyticsAPITests {
  func usage() {
    // MARK: - Analytics

    Analytics.logEvent("event_name", parameters: ["param": 1])
    Analytics.setUserProperty("value", forName: "name")
    Analytics.setUserID("user_id")
    Analytics.setAnalyticsCollectionEnabled(true)
    Analytics.setSessionTimeoutInterval(3600.0)
    let _: String? = Analytics.appInstanceID()
    Analytics.resetAnalyticsData()
    Analytics.setDefaultEventParameters(["default": 100])

    Analytics.sessionID { sessionID, error in }
    #if compiler(>=5.5.2) && canImport(_Concurrency)
      if #available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
        Task {
          let _: Int64? = try? await Analytics.sessionID()
        }
      }
    #endif // compiler(>=5.5.2) && canImport(_Concurrency)

    // MARK: - AppDelegate

    Analytics.handleEvents(forBackgroundURLSession: "session_id", completionHandler: {})
    #if compiler(>=5.5.2) && canImport(_Concurrency)
      if #available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 7.0, *) {
        Task {
          await Analytics.handleEvents(forBackgroundURLSession: "session_id")
        }
      }
    #endif // compiler(>=5.5.2) && canImport(_Concurrency)
    Analytics.handleOpen(URL(string: "https://google.com")!)
    Analytics.handleUserActivity(NSUserActivity(activityType: "editing"))

    // MARK: - Consent

    Analytics.setConsent([.analyticsStorage: .granted, .adStorage: .denied])

    // MARK: - OnDeviceConversion

    Analytics.initiateOnDeviceConversionMeasurement(emailAddress: "test@gmail.com")

    // MARK: - EventNames

    let _: [String] = [
      AnalyticsEventAdImpression,
      AnalyticsEventAddPaymentInfo,
      AnalyticsEventAddShippingInfo,
      AnalyticsEventAddToCart,
      AnalyticsEventAddToWishlist,
      AnalyticsEventAppOpen,
      AnalyticsEventBeginCheckout,
      AnalyticsEventCampaignDetails,
      AnalyticsEventEarnVirtualCurrency,
      AnalyticsEventGenerateLead,
      AnalyticsEventJoinGroup,
      AnalyticsEventLevelEnd,
      AnalyticsEventLevelStart,
      AnalyticsEventLevelUp,
      AnalyticsEventLogin,
      AnalyticsEventPostScore,
      AnalyticsEventPurchase,
      AnalyticsEventRefund,
      AnalyticsEventRemoveFromCart,
      AnalyticsEventScreenView,
      AnalyticsEventSearch,
      AnalyticsEventSelectContent,
      AnalyticsEventSelectItem,
      AnalyticsEventSelectPromotion,
      AnalyticsEventShare,
      AnalyticsEventSignUp,
      AnalyticsEventSpendVirtualCurrency,
      AnalyticsEventTutorialBegin,
      AnalyticsEventTutorialComplete,
      AnalyticsEventUnlockAchievement,
      AnalyticsEventViewCart,
      AnalyticsEventViewItem,
      AnalyticsEventViewItemList,
      AnalyticsEventViewPromotion,
      AnalyticsEventViewSearchResults,
    ]

    // MARK: - ParameterNames

    let _: [String] = [
      AnalyticsParameterAchievementID,
      AnalyticsParameterAdFormat,
      AnalyticsParameterAdNetworkClickID,
      AnalyticsParameterAdPlatform,
      AnalyticsParameterAdSource,
      AnalyticsParameterAdUnitName,
      AnalyticsParameterAffiliation,
      AnalyticsParameterCP1,
      AnalyticsParameterCampaign,
      AnalyticsParameterCampaignID,
      AnalyticsParameterCharacter,
      AnalyticsParameterContent,
      AnalyticsParameterContentType,
      AnalyticsParameterCoupon,
      AnalyticsParameterCreativeFormat,
      AnalyticsParameterCreativeName,
      AnalyticsParameterCreativeSlot,
      AnalyticsParameterCurrency,
      AnalyticsParameterDestination,
      AnalyticsParameterDiscount,
      AnalyticsParameterEndDate,
      AnalyticsParameterExtendSession,
      AnalyticsParameterFlightNumber,
      AnalyticsParameterGroupID,
      AnalyticsParameterIndex,
      AnalyticsParameterItemBrand,
      AnalyticsParameterItemCategory,
      AnalyticsParameterItemCategory2,
      AnalyticsParameterItemCategory3,
      AnalyticsParameterItemCategory4,
      AnalyticsParameterItemCategory5,
      AnalyticsParameterItemID,
      AnalyticsParameterItemListID,
      AnalyticsParameterItemListName,
      AnalyticsParameterItemName,
      AnalyticsParameterItemVariant,
      AnalyticsParameterItems,
      AnalyticsParameterLevel,
      AnalyticsParameterLevelName,
      AnalyticsParameterLocation,
      AnalyticsParameterLocationID,
      AnalyticsParameterMarketingTactic,
      AnalyticsParameterMedium,
      AnalyticsParameterMethod,
      AnalyticsParameterNumberOfNights,
      AnalyticsParameterNumberOfPassengers,
      AnalyticsParameterNumberOfRooms,
      AnalyticsParameterOrigin,
      AnalyticsParameterPaymentType,
      AnalyticsParameterPrice,
      AnalyticsParameterPromotionID,
      AnalyticsParameterPromotionName,
      AnalyticsParameterQuantity,
      AnalyticsParameterScore,
      AnalyticsParameterScreenClass,
      AnalyticsParameterScreenName,
      AnalyticsParameterSearchTerm,
      AnalyticsParameterShipping,
      AnalyticsParameterShippingTier,
      AnalyticsParameterSource,
      AnalyticsParameterSourcePlatform,
      AnalyticsParameterStartDate,
      AnalyticsParameterSuccess,
      AnalyticsParameterTax,
      AnalyticsParameterTerm,
      AnalyticsParameterTransactionID,
      AnalyticsParameterTravelClass,
      AnalyticsParameterValue,
      AnalyticsParameterVirtualCurrencyName,
    ]

    // MARK: - UserPropertyNames

    let _: [String] = [
      AnalyticsUserPropertyAllowAdPersonalizationSignals,
      AnalyticsUserPropertySignUpMethod,
    ]
  }
}
