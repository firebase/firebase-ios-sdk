//
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
//

// MARK: This file is used to test the coverage of using Analytics APIs from Objective-C.

@import Foundation;
@import XCTest;

@import FirebaseAnalytics;

@interface ObjCAPICoverage : XCTestCase
@end

@implementation ObjCAPICoverage
- (NSString *)analyticsTests {
  [FIRAnalytics logEventWithName:@"event_name" parameters:@{@"param" : @1}];
  [FIRAnalytics setUserPropertyString:@"value" forName:@"name"];
  [FIRAnalytics setUserID:@"userid"];
  [FIRAnalytics setAnalyticsCollectionEnabled:YES];
  [FIRAnalytics setSessionTimeoutInterval:360.0];
  [FIRAnalytics resetAnalyticsData];
  [FIRAnalytics setDefaultEventParameters:@{@"default" : @100}];
  NSString *str = [FIRAnalytics appInstanceID];

  [FIRAnalytics sessionIDWithCompletion:^(int64_t sessionID, NSError *_Nullable error){
  }];
  return str;
}

- (void)appDelegateTests:(NSURL *)url {
  [FIRAnalytics handleEventsForBackgroundURLSession:@"sessionID"
                                  completionHandler:^{
                                  }];
  [FIRAnalytics handleOpenURL:url];
  [FIRAnalytics handleUserActivity:[NSUserActivity init]];
}

- (void)consentTests:(NSURL *)url {
  [FIRAnalytics setConsent:@{
    FIRConsentTypeAdPersonalization : FIRConsentStatusGranted,
    FIRConsentTypeAdStorage : FIRConsentStatusDenied,
    FIRConsentTypeAdUserData : FIRConsentStatusGranted,
    FIRConsentTypeAnalyticsStorage : FIRConsentStatusDenied,
  }];
}

- (void)onDeviceConversionTests:(NSURL *)url {
  [FIRAnalytics initiateOnDeviceConversionMeasurementWithEmailAddress:@"a@.a.com"];
  [FIRAnalytics initiateOnDeviceConversionMeasurementWithPhoneNumber:@"+15555555555"];
  [FIRAnalytics initiateOnDeviceConversionMeasurementWithHashedEmailAddress:[NSData data]];
  [FIRAnalytics initiateOnDeviceConversionMeasurementWithHashedPhoneNumber:[NSData data]];
}

- (NSArray<NSString *> *)eventNames {
  return @[
    kFIREventAdImpression,
    kFIREventAddPaymentInfo,
    kFIREventAddShippingInfo,
    kFIREventAddToCart,
    kFIREventAddToWishlist,
    kFIREventAppOpen,
    kFIREventBeginCheckout,
    kFIREventCampaignDetails,
    kFIREventEarnVirtualCurrency,
    kFIREventGenerateLead,
    kFIREventJoinGroup,
    kFIREventLevelEnd,
    kFIREventLevelStart,
    kFIREventLevelUp,
    kFIREventLogin,
    kFIREventPostScore,
    kFIREventPurchase,
    kFIREventRefund,
    kFIREventRemoveFromCart,
    kFIREventScreenView,
    kFIREventSearch,
    kFIREventSelectContent,
    kFIREventSelectItem,
    kFIREventSelectPromotion,
    kFIREventShare,
    kFIREventSignUp,
    kFIREventSpendVirtualCurrency,
    kFIREventTutorialBegin,
    kFIREventTutorialComplete,
    kFIREventUnlockAchievement,
    kFIREventViewCart,
    kFIREventViewItem,
    kFIREventViewItemList,
    kFIREventViewPromotion,
    kFIREventViewSearchResults,
  ];
}

- (NSArray<NSString *> *)parameterNames {
  return @[
    kFIRParameterAchievementID,
    kFIRParameterAdFormat,
    kFIRParameterAdNetworkClickID,
    kFIRParameterAdPlatform,
    kFIRParameterAdSource,
    kFIRParameterAdUnitName,
    kFIRParameterAffiliation,
    kFIRParameterCP1,
    kFIRParameterCampaign,
    kFIRParameterCampaignID,
    kFIRParameterCharacter,
    kFIRParameterContent,
    kFIRParameterContentType,
    kFIRParameterCoupon,
    kFIRParameterCreativeFormat,
    kFIRParameterCreativeName,
    kFIRParameterCreativeSlot,
    kFIRParameterCurrency,
    kFIRParameterDestination,
    kFIRParameterDiscount,
    kFIRParameterEndDate,
    kFIRParameterExtendSession,
    kFIRParameterFlightNumber,
    kFIRParameterGroupID,
    kFIRParameterIndex,
    kFIRParameterItemBrand,
    kFIRParameterItemCategory,
    kFIRParameterItemCategory2,
    kFIRParameterItemCategory3,
    kFIRParameterItemCategory4,
    kFIRParameterItemCategory5,
    kFIRParameterItemID,
    kFIRParameterItemListID,
    kFIRParameterItemListName,
    kFIRParameterItemName,
    kFIRParameterItemVariant,
    kFIRParameterItems,
    kFIRParameterLevel,
    kFIRParameterLevelName,
    kFIRParameterLocation,
    kFIRParameterLocationID,
    kFIRParameterMarketingTactic,
    kFIRParameterMedium,
    kFIRParameterMethod,
    kFIRParameterNumberOfNights,
    kFIRParameterNumberOfPassengers,
    kFIRParameterNumberOfRooms,
    kFIRParameterOrigin,
    kFIRParameterPaymentType,
    kFIRParameterPrice,
    kFIRParameterPromotionID,
    kFIRParameterPromotionName,
    kFIRParameterQuantity,
    kFIRParameterScore,
    kFIRParameterScreenClass,
    kFIRParameterScreenName,
    kFIRParameterSearchTerm,
    kFIRParameterShipping,
    kFIRParameterShippingTier,
    kFIRParameterSource,
    kFIRParameterSourcePlatform,
    kFIRParameterStartDate,
    kFIRParameterSuccess,
    kFIRParameterTax,
    kFIRParameterTerm,
    kFIRParameterTransactionID,
    kFIRParameterTravelClass,
    kFIRParameterValue,
    kFIRParameterVirtualCurrencyName,
  ];
}

- (NSArray<NSString *> *)userPropertyNames {
  return @[
    kFIRUserPropertyAllowAdPersonalizationSignals,
    kFIRUserPropertySignUpMethod,
  ];
}
@end
