/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <XCTest/XCTest.h>

#import "FirebaseDynamicLinks/Sources/FDLURLComponents/FDLURLComponents+Private.h"
#import "FirebaseDynamicLinks/Sources/FDLURLComponents/FIRDynamicLinkComponentsKeyProvider.h"

#import <OCMock/OCMock.h>

static NSString *const kFDLURLDomain = @"https://xyz.page.link";
static NSString *const kFDLURLCustomDomain = @"https://foo.com/path";

@interface FDLURLComponentsTests : XCTestCase
@end

@implementation FDLURLComponentsTests

#pragma mark - FIRDynamicLinkGoogleAnalyticsParameters

- (void)testAnalyticsParamsFactoryReturnsInstanceOfCorrectClass {
  id returnValue = [FIRDynamicLinkGoogleAnalyticsParameters parameters];
  XCTAssertTrue([returnValue isKindOfClass:[FIRDynamicLinkGoogleAnalyticsParameters class]]);
}

- (void)testAnalyticsParamsFactoryReturnsInstanceWithAllNilProperties {
  FIRDynamicLinkGoogleAnalyticsParameters *params =
      [FIRDynamicLinkGoogleAnalyticsParameters parameters];

  XCTAssertNil(params.source);
  XCTAssertNil(params.medium);
  XCTAssertNil(params.campaign);
  XCTAssertNil(params.term);
  XCTAssertNil(params.content);
}

- (void)testAnalyticsParamsPropertiesSetProperly {
  FIRDynamicLinkGoogleAnalyticsParameters *params =
      [FIRDynamicLinkGoogleAnalyticsParameters parameters];

  params.source = @"s";
  params.medium = @"m";
  params.campaign = @"ca";
  params.term = @"t";
  params.content = @"co";

  XCTAssertEqualObjects(params.source, @"s");
  XCTAssertEqualObjects(params.medium, @"m");
  XCTAssertEqualObjects(params.campaign, @"ca");
  XCTAssertEqualObjects(params.term, @"t");
  XCTAssertEqualObjects(params.content, @"co");

  params.source = nil;
  params.medium = nil;
  params.campaign = nil;
  params.term = nil;
  params.content = nil;

  XCTAssertNil(params.source);
  XCTAssertNil(params.medium);
  XCTAssertNil(params.campaign);
  XCTAssertNil(params.term);
  XCTAssertNil(params.content);
}

- (void)testAnalyticsParamsDictionaryRepresentationReturnsCorrectDictionaryFull {
  FIRDynamicLinkGoogleAnalyticsParameters *params =
      [FIRDynamicLinkGoogleAnalyticsParameters parameters];

  params.source = @"s";
  params.medium = @"m";
  params.campaign = @"ca";
  params.term = @"t";
  params.content = @"co";

  NSDictionary *expectedDictionary = @{
    @"utm_source" : @"s",
    @"utm_medium" : @"m",
    @"utm_campaign" : @"ca",
    @"utm_term" : @"t",
    @"utm_content" : @"co",
  };

  XCTAssertEqualObjects(expectedDictionary, params.dictionaryRepresentation);
}

- (void)testAnalyticsParamsDictionaryRepresentationReturnsCorrectDictionaryEmpty {
  FIRDynamicLinkGoogleAnalyticsParameters *params =
      [FIRDynamicLinkGoogleAnalyticsParameters parameters];
  XCTAssertEqualObjects(@{}, params.dictionaryRepresentation);
}

- (void)testAnalyticsParamsFactoryWithParamsReturnsInstanceOfCorrectClass {
  id returnValue = [FIRDynamicLinkGoogleAnalyticsParameters parametersWithSource:@"s"
                                                                          medium:@"m"
                                                                        campaign:@"c"];
  XCTAssertTrue([returnValue isKindOfClass:[FIRDynamicLinkGoogleAnalyticsParameters class]]);
}

- (void)testAnalyticsParamsFactoryWithParamsReturnsInstanceWithCorrectInitialPropertyValues {
  FIRDynamicLinkGoogleAnalyticsParameters *params =
      [FIRDynamicLinkGoogleAnalyticsParameters parametersWithSource:@"s" medium:@"m" campaign:@"c"];

  XCTAssertEqualObjects(params.source, @"s");
  XCTAssertEqualObjects(params.medium, @"m");
  XCTAssertEqualObjects(params.campaign, @"c");
  XCTAssertNil(params.term);
  XCTAssertNil(params.content);
}

#pragma mark - FIRDynamicLinkIOSParameters

- (void)testIOSParamsFactoryReturnsInstanceOfCorrectClass {
  id returnValue = [FIRDynamicLinkIOSParameters parametersWithBundleID:@"com.iphone.app"];
  XCTAssertTrue([returnValue isKindOfClass:[FIRDynamicLinkIOSParameters class]]);
}

- (void)testIOSParamsFactoryReturnsInstanceWithAllOptionalNilProperties {
  FIRDynamicLinkIOSParameters *params =
      [FIRDynamicLinkIOSParameters parametersWithBundleID:@"com.iphone.app"];

  XCTAssertNil(params.fallbackURL);
  XCTAssertNil(params.customScheme);
  XCTAssertNil(params.minimumAppVersion);
  XCTAssertNil(params.iPadBundleID);
  XCTAssertNil(params.iPadFallbackURL);
  XCTAssertNil(params.appStoreID);
}

- (void)testIOSParamsPropertiesSetProperly {
  FIRDynamicLinkIOSParameters *params =
      [FIRDynamicLinkIOSParameters parametersWithBundleID:@"com.iphone.app"];

  params.fallbackURL = [NSURL URLWithString:@"https://google.com/iphone"];
  params.customScheme = @"mycustomsheme";
  params.minimumAppVersion = @"1.2.3";
  params.iPadBundleID = @"com.ipad.app";
  params.iPadFallbackURL = [NSURL URLWithString:@"https://google.com/ipad"];
  params.appStoreID = @"666";

  XCTAssertEqualObjects(params.bundleID, @"com.iphone.app");
  XCTAssertEqualObjects(params.fallbackURL, [NSURL URLWithString:@"https://google.com/iphone"]);
  XCTAssertEqualObjects(params.customScheme, @"mycustomsheme");
  XCTAssertEqualObjects(params.minimumAppVersion, @"1.2.3");
  XCTAssertEqualObjects(params.iPadBundleID, @"com.ipad.app");
  XCTAssertEqualObjects(params.iPadFallbackURL, [NSURL URLWithString:@"https://google.com/ipad"]);
  XCTAssertEqualObjects(params.appStoreID, @"666");

  params.fallbackURL = nil;
  params.customScheme = nil;
  params.minimumAppVersion = nil;
  params.iPadBundleID = nil;
  params.iPadFallbackURL = nil;
  params.appStoreID = nil;

  XCTAssertNil(params.fallbackURL);
  XCTAssertNil(params.customScheme);
  XCTAssertNil(params.minimumAppVersion);
  XCTAssertNil(params.iPadBundleID);
  XCTAssertNil(params.iPadFallbackURL);
  XCTAssertNil(params.appStoreID);
}

- (void)testIOSParamsDictionaryRepresentationReturnsCorrectDictionaryFull {
  FIRDynamicLinkIOSParameters *params =
      [FIRDynamicLinkIOSParameters parametersWithBundleID:@"com.iphone.app"];

  params.fallbackURL = [NSURL URLWithString:@"https://google.com/iphone"];
  params.customScheme = @"mycustomscheme";
  params.minimumAppVersion = @"1.2.3";
  params.iPadBundleID = @"com.ipad.app";
  params.iPadFallbackURL = [NSURL URLWithString:@"https://google.com/ipad"];
  params.appStoreID = @"666";

  NSDictionary *expectedDictionary = @{
    @"ibi" : @"com.iphone.app",
    @"ifl" : [NSURL URLWithString:@"https://google.com/iphone"].absoluteString,
    @"ius" : @"mycustomscheme",
    @"imv" : @"1.2.3",
    @"ipbi" : @"com.ipad.app",
    @"ipfl" : [NSURL URLWithString:@"https://google.com/ipad"].absoluteString,
    @"isi" : @"666"
  };

  XCTAssertEqualObjects(expectedDictionary, params.dictionaryRepresentation);
}

- (void)testIOSParamsDictionaryRepresentationReturnsCorrectDictionaryOnlyReqParams {
  FIRDynamicLinkIOSParameters *params =
      [FIRDynamicLinkIOSParameters parametersWithBundleID:@"com.iphone.app"];
  XCTAssertEqualObjects(@{@"ibi" : @"com.iphone.app"}, params.dictionaryRepresentation);
}

#pragma mark - FIRDynamicLinkItunesConnectAnalyticsParameters

- (void)testIOSAppStoreParamsFactoryReturnsInstanceOfCorrectClass {
  id returnValue = [FIRDynamicLinkItunesConnectAnalyticsParameters parameters];
  XCTAssertTrue([returnValue isKindOfClass:[FIRDynamicLinkItunesConnectAnalyticsParameters class]]);
}

- (void)testIOSAppStoreParamsFactoryReturnsInstanceWithAllNilProperties {
  FIRDynamicLinkItunesConnectAnalyticsParameters *params =
      [FIRDynamicLinkItunesConnectAnalyticsParameters parameters];

  XCTAssertNil(params.affiliateToken);
  XCTAssertNil(params.campaignToken);
  XCTAssertNil(params.providerToken);
}

- (void)testIOSAppStoreParamsPropertiesSetProperly {
  FIRDynamicLinkItunesConnectAnalyticsParameters *params =
      [FIRDynamicLinkItunesConnectAnalyticsParameters parameters];

  params.affiliateToken = @"affiliate";
  params.campaignToken = @"campaign";
  params.providerToken = @"provider";

  XCTAssertEqualObjects(params.affiliateToken, @"affiliate");
  XCTAssertEqualObjects(params.campaignToken, @"campaign");
  XCTAssertEqualObjects(params.providerToken, @"provider");

  params.affiliateToken = nil;
  params.campaignToken = nil;
  params.providerToken = nil;

  XCTAssertNil(params.affiliateToken);
  XCTAssertNil(params.campaignToken);
  XCTAssertNil(params.providerToken);
}

- (void)testIOSAppStoreDictionaryRepresentationReturnsCorrectDictionaryFull {
  FIRDynamicLinkItunesConnectAnalyticsParameters *params =
      [FIRDynamicLinkItunesConnectAnalyticsParameters parameters];

  params.affiliateToken = @"affiliate";
  params.campaignToken = @"campaign";
  params.providerToken = @"provider";

  NSDictionary *expectedDictionary = @{
    @"at" : @"affiliate",
    @"ct" : @"campaign",
    @"pt" : @"provider",
  };

  XCTAssertEqualObjects(expectedDictionary, params.dictionaryRepresentation);
}

- (void)testIOSAppStoreDictionaryRepresentationReturnsCorrectDictionaryEmpty {
  FIRDynamicLinkItunesConnectAnalyticsParameters *params =
      [FIRDynamicLinkItunesConnectAnalyticsParameters parameters];
  XCTAssertEqualObjects(@{}, params.dictionaryRepresentation);
}

#pragma mark - FIRDynamicLinkAndroidParameters

- (void)testAndroidParamsFactoryReturnsInstanceOfCorrectClass {
  id returnValue =
      [FIRDynamicLinkAndroidParameters parametersWithPackageName:@"com.google.android.gms"];
  XCTAssertTrue([returnValue isKindOfClass:[FIRDynamicLinkAndroidParameters class]]);
}

- (void)testAndroidParamsFactoryReturnsInstanceWithAllOptionalNilProperties {
  FIRDynamicLinkAndroidParameters *params =
      [FIRDynamicLinkAndroidParameters parametersWithPackageName:@"com.google.android.gms"];

  XCTAssertNil(params.fallbackURL);
  XCTAssertEqual(params.minimumVersion, 0);
}

- (void)testAndroidParamsPropertiesSetProperly {
  FIRDynamicLinkAndroidParameters *params =
      [FIRDynamicLinkAndroidParameters parametersWithPackageName:@"com.google.android.gms"];

  params.fallbackURL = [NSURL URLWithString:@"https://google.com/android"];
  params.minimumVersion = 14;

  XCTAssertEqualObjects(params.packageName, @"com.google.android.gms");
  XCTAssertEqualObjects(params.fallbackURL, [NSURL URLWithString:@"https://google.com/android"]);
  XCTAssertEqual(params.minimumVersion, 14);

  params.fallbackURL = nil;
  params.minimumVersion = 0;

  XCTAssertNil(params.fallbackURL);
  XCTAssertEqual(params.minimumVersion, 0);
}

- (void)testAndroidParamsDictionaryRepresentationReturnsCorrectDictionaryFull {
  FIRDynamicLinkAndroidParameters *params =
      [FIRDynamicLinkAndroidParameters parametersWithPackageName:@"com.google.android.gms"];

  params.fallbackURL = [NSURL URLWithString:@"https://google.com/android"];
  params.minimumVersion = 14;

  NSDictionary *expectedDictionary = @{
    @"apn" : @"com.google.android.gms",
    @"afl" : [NSURL URLWithString:@"https://google.com/android"].absoluteString,
    @"amv" : @"14",
  };

  XCTAssertEqualObjects(expectedDictionary, params.dictionaryRepresentation);
}

- (void)testAndroidParamsDictionaryRepresentationReturnsCorrectDictionaryEmpty {
  FIRDynamicLinkAndroidParameters *params =
      [FIRDynamicLinkAndroidParameters parametersWithPackageName:@"com.google.android.gms"];
  XCTAssertEqualObjects(@{@"apn" : @"com.google.android.gms"}, params.dictionaryRepresentation);
}

#pragma mark - FIRDynamicLinkSocialMetaTagParameters

- (void)testSocialParamsFactoryReturnsInstanceOfCorrectClass {
  id returnValue = [FIRDynamicLinkSocialMetaTagParameters parameters];
  XCTAssertTrue([returnValue isKindOfClass:[FIRDynamicLinkSocialMetaTagParameters class]]);
}

- (void)testSocialParamsFactoryReturnsInstanceWithAllNilProperties {
  FIRDynamicLinkSocialMetaTagParameters *params =
      [FIRDynamicLinkSocialMetaTagParameters parameters];

  XCTAssertNil(params.title);
  XCTAssertNil(params.descriptionText);
  XCTAssertNil(params.imageURL);
}

- (void)testSocialParamsPropertiesSetProperly {
  FIRDynamicLinkSocialMetaTagParameters *params =
      [FIRDynamicLinkSocialMetaTagParameters parameters];

  params.title = @"title";
  params.descriptionText = @"description";
  params.imageURL = [NSURL URLWithString:@"https://google.com/someimage"];

  XCTAssertEqualObjects(params.title, @"title");
  XCTAssertEqualObjects(params.descriptionText, @"description");
  XCTAssertEqualObjects(params.imageURL, [NSURL URLWithString:@"https://google.com/someimage"]);

  params.title = nil;
  params.descriptionText = nil;
  params.imageURL = nil;

  XCTAssertNil(params.title);
  XCTAssertNil(params.descriptionText);
  XCTAssertNil(params.imageURL);
}

- (void)testSocialParamsDictionaryRepresentationReturnsCorrectDictionaryFull {
  FIRDynamicLinkSocialMetaTagParameters *params =
      [FIRDynamicLinkSocialMetaTagParameters parameters];

  params.title = @"title";
  params.descriptionText = @"description";
  params.imageURL = [NSURL URLWithString:@"https://google.com/someimage"];

  NSDictionary *expectedDictionary = @{
    @"st" : @"title",
    @"sd" : @"description",
    @"si" : [NSURL URLWithString:@"https://google.com/someimage"].absoluteString,
  };

  XCTAssertEqualObjects(expectedDictionary, params.dictionaryRepresentation);
}

- (void)testSocialParamsDictionaryRepresentationReturnsCorrectDictionaryEmpty {
  FIRDynamicLinkSocialMetaTagParameters *params =
      [FIRDynamicLinkSocialMetaTagParameters parameters];
  XCTAssertEqualObjects(@{}, params.dictionaryRepresentation);
}

#pragma mark - FIRDynamicLinkNavigationInfoParameters

- (void)testNavigationOptionsReturnsCorrectClass {
  id returnValue = [FIRDynamicLinkNavigationInfoParameters parameters];
  XCTAssertTrue([returnValue isKindOfClass:[FIRDynamicLinkNavigationInfoParameters class]]);
}

- (void)testNavigationOptionsFactoryReturnsInstanceWithAllNilProperties {
  FIRDynamicLinkNavigationInfoParameters *options =
      [FIRDynamicLinkNavigationInfoParameters parameters];

  XCTAssertEqual(options.forcedRedirectEnabled, NO);
}

- (void)testNavigationOptionsParamsPropertiesSetProperly {
  FIRDynamicLinkNavigationInfoParameters *options =
      [FIRDynamicLinkNavigationInfoParameters parameters];

  options.forcedRedirectEnabled = YES;

  XCTAssertEqual(options.forcedRedirectEnabled, YES);

  options.forcedRedirectEnabled = NO;

  XCTAssertEqual(options.forcedRedirectEnabled, NO);
}

#pragma mark - FIRDynamicLinkOtherPlatformParameters

- (void)testOtherPlatformParametersReturnsCorrectClass {
  id returnValue = [FIRDynamicLinkOtherPlatformParameters parameters];
  XCTAssertTrue([returnValue isKindOfClass:[FIRDynamicLinkOtherPlatformParameters class]]);
}

- (void)testOtherPlatformParametersFactoryReturnsInstanceWithAllNilProperties {
  FIRDynamicLinkOtherPlatformParameters *options =
      [FIRDynamicLinkOtherPlatformParameters parameters];

  XCTAssertNil(options.fallbackUrl);
}

- (void)testOtherPlatformParametersParamsPropertiesSetProperly {
  FIRDynamicLinkOtherPlatformParameters *options =
      [FIRDynamicLinkOtherPlatformParameters parameters];

  options.fallbackUrl = [NSURL URLWithString:@"https://google.com"];

  XCTAssertEqualObjects(options.fallbackUrl, [NSURL URLWithString:@"https://google.com"]);

  options.fallbackUrl = nil;

  XCTAssertNil(options.fallbackUrl);
}

#pragma mark - FIRDynamicLinkComponentsOptions

- (void)testLinkOptionsFactoryReturnsInstanceOfCorrectClass {
  id returnValue = [FIRDynamicLinkComponentsOptions options];
  XCTAssertTrue([returnValue isKindOfClass:[FIRDynamicLinkComponentsOptions class]]);
}

- (void)testLinkOptionsParamsFactoryReturnsInstanceWithAllNilProperties {
  FIRDynamicLinkComponentsOptions *options = [FIRDynamicLinkComponentsOptions options];

  XCTAssertEqual(options.pathLength, FIRShortDynamicLinkPathLengthDefault);
}

- (void)testLinkOptionsParamsPropertiesSetProperly {
  FIRDynamicLinkComponentsOptions *options = [FIRDynamicLinkComponentsOptions options];

  options.pathLength = FIRShortDynamicLinkPathLengthUnguessable;

  XCTAssertEqual(options.pathLength, FIRShortDynamicLinkPathLengthUnguessable);

  options.pathLength = FIRShortDynamicLinkPathLengthShort;

  XCTAssertEqual(options.pathLength, FIRShortDynamicLinkPathLengthShort);
}

#pragma mark - FIRDynamicLinkComponents

- (void)testFDLComponentsFactoryReturnsInstanceOfCorrectClass {
  NSURL *link = [NSURL URLWithString:@"https://google.com"];
  id returnValue = [FIRDynamicLinkComponents componentsWithLink:link domainURIPrefix:kFDLURLDomain];
  XCTAssertTrue([returnValue isKindOfClass:[FIRDynamicLinkComponents class]]);
}

- (void)testFDLComponentsFactoryReturnsInstanceWithAllNilProperties {
  NSURL *link = [NSURL URLWithString:@"https://google.com"];
  FIRDynamicLinkComponents *components =
      [FIRDynamicLinkComponents componentsWithLink:link domainURIPrefix:kFDLURLDomain];

  XCTAssertNil(components.analyticsParameters);
  XCTAssertNil(components.socialMetaTagParameters);
  XCTAssertNil(components.iOSParameters);
  XCTAssertNil(components.iTunesConnectParameters);
  XCTAssertNil(components.analyticsParameters);
  XCTAssertNil(components.options);
}

- (void)testFDLComponentsCreatesSimplestLinkCorrectly {
  NSString *linkString = @"https://google.com";
  NSString *encodedLinkString = @"https%3A%2F%2Fgoogle%2Ecom";
  NSURL *link = [NSURL URLWithString:linkString];

  NSString *expectedURLString =
      [NSString stringWithFormat:@"%@/?link=%@", kFDLURLDomain, encodedLinkString];
  NSURL *expectedURL = [NSURL URLWithString:expectedURLString];

  FIRDynamicLinkComponents *components =
      [FIRDynamicLinkComponents componentsWithLink:link domainURIPrefix:kFDLURLDomain];
  NSURL *actualURL = components.url;

  XCTAssertEqualObjects(actualURL, expectedURL);
}

- (void)testFDLComponentsCustomDomainWithPath {
  NSString *linkString = @"https://google.com";
  NSString *encodedLinkString = @"https%3A%2F%2Fgoogle%2Ecom";
  NSURL *link = [NSURL URLWithString:linkString];

  NSString *expectedURLString =
      [NSString stringWithFormat:@"%@/?link=%@", kFDLURLCustomDomain, encodedLinkString];
  NSURL *expectedURL = [NSURL URLWithString:expectedURLString];

  FIRDynamicLinkComponents *components =
      [FIRDynamicLinkComponents componentsWithLink:link domainURIPrefix:kFDLURLCustomDomain];
  NSURL *actualURL = components.url;

  XCTAssertEqualObjects(actualURL, expectedURL);
}

- (void)testFDLComponentsFailsOnMalformedDomainURIPrefix {
  NSString *linkString = @"https://google.com";
  NSURL *link = [NSURL URLWithString:linkString];

  FIRDynamicLinkComponents *components =
      [FIRDynamicLinkComponents componentsWithLink:link
                                   domainURIPrefix:@"this is invalid domain URI Prefix"];

  XCTAssertNil(components.url);
}

- (void)testFDLComponentsNotNilOnDomainWithHTTPScheme {
  NSString *linkString = @"https://google.com";
  NSURL *link = [NSURL URLWithString:linkString];

  FIRDynamicLinkComponents *components =
      [FIRDynamicLinkComponents componentsWithLink:link domainURIPrefix:@"https://xyz.page.link"];

  XCTAssertNotNil(components);
}

- (void)testFDLComponentsNotNilOnDomainWithHTTPSScheme {
  NSString *linkString = @"https://google.com";
  NSURL *link = [NSURL URLWithString:linkString];

  FIRDynamicLinkComponents *components =
      [FIRDynamicLinkComponents componentsWithLink:link domainURIPrefix:@"https://xyz.page.link"];

  XCTAssertNotNil(components);
}

- (void)testFDLComponentsFailsOnMalformedDomain {
  NSString *linkString = @"https://google.com";
  NSURL *link = [NSURL URLWithString:linkString];

  FIRDynamicLinkComponents *components =
      [FIRDynamicLinkComponents componentsWithLink:link
                                   domainURIPrefix:@"this is invalid domain URI Prefix"];

  XCTAssertNil(components);
}

- (void)testFDLComponentsCreatesFullLinkCorrectly {
  FIRDynamicLinkGoogleAnalyticsParameters *analyticsParams =
      [FIRDynamicLinkGoogleAnalyticsParameters parameters];
  analyticsParams.source = @"s";
  analyticsParams.medium = @"m";
  analyticsParams.campaign = @"ca";
  analyticsParams.term = @"t";
  analyticsParams.content = @"co";

  FIRDynamicLinkIOSParameters *iosParams =
      [FIRDynamicLinkIOSParameters parametersWithBundleID:@"com.iphone.app"];
  iosParams.fallbackURL = [NSURL URLWithString:@"https://google.com/iphone"];
  iosParams.customScheme = @"mycustomsheme";
  iosParams.minimumAppVersion = @"1.2.3";
  iosParams.iPadBundleID = @"com.ipad.app";
  iosParams.iPadFallbackURL = [NSURL URLWithString:@"https://google.com/ipad"];
  iosParams.appStoreID = @"666";

  FIRDynamicLinkItunesConnectAnalyticsParameters *itcParams =
      [FIRDynamicLinkItunesConnectAnalyticsParameters parameters];
  itcParams.affiliateToken = @"affiliate";
  itcParams.campaignToken = @"campaign";
  itcParams.providerToken = @"provider";

  FIRDynamicLinkAndroidParameters *androidParams =
      [FIRDynamicLinkAndroidParameters parametersWithPackageName:@"com.google.android.gms"];
  androidParams.fallbackURL = [NSURL URLWithString:@"https://google.com/android"];
  androidParams.minimumVersion = 14;

  FIRDynamicLinkSocialMetaTagParameters *socialParams =
      [FIRDynamicLinkSocialMetaTagParameters parameters];
  socialParams.title = @"title";
  socialParams.descriptionText = @"description";
  socialParams.imageURL = [NSURL URLWithString:@"https://google.com/someimage"];

  FIRDynamicLinkOtherPlatformParameters *otherPlatformParams =
      [FIRDynamicLinkOtherPlatformParameters parameters];
  otherPlatformParams.fallbackUrl =
      [NSURL URLWithString:@"https://google.com/fallbackForOtherPlatform"];

  FIRDynamicLinkNavigationInfoParameters *navInfo =
      [FIRDynamicLinkNavigationInfoParameters parameters];
  navInfo.forcedRedirectEnabled = YES;

  FIRDynamicLinkComponentsOptions *options = [FIRDynamicLinkComponentsOptions options];
  options.pathLength = FIRShortDynamicLinkPathLengthUnguessable;

  NSURL *link = [NSURL URLWithString:@"https://google.com"];
  FIRDynamicLinkComponents *fdlComponents =
      [FIRDynamicLinkComponents componentsWithLink:link domainURIPrefix:kFDLURLDomain];
  fdlComponents.analyticsParameters = analyticsParams;
  fdlComponents.iOSParameters = iosParams;
  fdlComponents.iTunesConnectParameters = itcParams;
  fdlComponents.androidParameters = androidParams;
  fdlComponents.socialMetaTagParameters = socialParams;
  fdlComponents.navigationInfoParameters = navInfo;
  fdlComponents.otherPlatformParameters = otherPlatformParams;
  fdlComponents.options = options;

  // This is a long FDL URL that has been verified to be a correct representation of the expected
  // URL. Since the parameters are not guaranteed to be in any specific order, we must compare
  // arrays of properties of the URLs rather than the URLs themselves.
  NSString *possibleExpectedURLString =
      @"https://xyz.page.link/?afl=https%3A%2F%2Fgoogle%2Ecom%2F"
       "android&amv=14&apn=com.google.android.gms&ibi=com%2Eiphone%2Eapp&utm_term=t&link=https%3A%"
       "2F"
       "%2Fgoogle%2Ecom&ipbi=com%2Eipad%2Eapp&ius=mycustomsheme&ifl=https%3A%2F%2Fgoogle%2Ecom%2"
       "Fiphone&isi=666&utm_content=co&utm_source=s&utm_medium=m&imv=1%2E2%2E3&ct=campaign&ipfl="
       "http"
       "s%3A%2F%2Fgoogle%2Ecom%2Fipad&si=https%3A%2F%2Fgoogle%2Ecom%2Fsomeimage&at=affiliate&pt="
       "prov"
       "ider&st=title&utm_campaign=ca&sd=description&efr=1&ofl=https%3A%2F%2Fgoogle%2Ecom%"
       "2Ffallback"
       "ForOtherPlatform";
  NSURL *possibleExpectedURL = [NSURL URLWithString:possibleExpectedURLString];
  NSURLComponents *expectedURLComponents =
      [NSURLComponents componentsWithString:possibleExpectedURLString];
  // sort both expected/actual arrays to prevent order influencing the test results
  NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
  NSArray<NSURLQueryItem *> *expectedURLQueryItems =
      [expectedURLComponents.queryItems sortedArrayUsingDescriptors:@[ sort ]];

  NSURL *actualURL = fdlComponents.url;
  NSURLComponents *actualURLComponents =
      [NSURLComponents componentsWithString:actualURL.absoluteString];
  NSArray<NSURLQueryItem *> *actualQueryItems =
      [actualURLComponents.queryItems sortedArrayUsingDescriptors:@[ sort ]];

  XCTAssertEqualObjects(actualQueryItems, expectedURLQueryItems);
  XCTAssertEqualObjects(actualURL.host, possibleExpectedURL.host);
}

- (void)testFDLComponentsCorrectlySetsPathLengthInRequest {
  NSURL *url = [NSURL URLWithString:@"https://google.com/abc"];
  NSURLRequest *request;
  NSDictionary *JSON;

  FIRDynamicLinkComponentsOptions *options = [FIRDynamicLinkComponentsOptions options];

  // Default path-length
  request = [FIRDynamicLinkComponents shorteningRequestForLongURL:url options:options];
  JSON = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
  XCTAssertNil(JSON[@"suffix"]);

  // Unguessable
  options.pathLength = FIRShortDynamicLinkPathLengthUnguessable;
  request = [FIRDynamicLinkComponents shorteningRequestForLongURL:url options:options];
  JSON = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
  XCTAssertTrue([JSON[@"suffix"][@"option"] isEqualToString:@"UNGUESSABLE"]);

  // Short
  options.pathLength = FIRShortDynamicLinkPathLengthShort;
  request = [FIRDynamicLinkComponents shorteningRequestForLongURL:url options:options];
  JSON = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
  XCTAssertTrue([JSON[@"suffix"][@"option"] isEqualToString:@"SHORT"]);
}

- (void)testShortenURL {
  NSString *shortURLString = @"https://xyz.page.link/abcd";

  // Mock key provider
  id keyProviderClassMock = OCMClassMock([FIRDynamicLinkComponentsKeyProvider class]);
  [[[keyProviderClassMock expect] andReturn:@"fake-api-key"] APIKey];

  id componentsClassMock = OCMClassMock([FIRDynamicLinkComponents class]);
  [[componentsClassMock expect]
      sendHTTPRequest:OCMOCK_ANY
           completion:[OCMArg checkWithBlock:^BOOL(id obj) {
             void (^completion)(NSData *_Nullable, NSError *_Nullable) = obj;
             NSDictionary *JSON = @{@"shortLink" : shortURLString};
             NSData *JSONData = [NSJSONSerialization dataWithJSONObject:JSON options:0 error:0];
             completion(JSONData, nil);
             return YES;
           }]];

  XCTestExpectation *expectation = [self expectationWithDescription:@"completion called"];
  NSURL *link = [NSURL URLWithString:@"https://google.com/abc"];
  FIRDynamicLinkComponents *components =
      [FIRDynamicLinkComponents componentsWithLink:link domainURIPrefix:kFDLURLDomain];
  [components
      shortenWithCompletion:^(NSURL *_Nullable shortURL, NSArray<NSString *> *_Nullable warnings,
                              NSError *_Nullable error) {
        XCTAssertEqualObjects(shortURL.absoluteString, shortURLString);
        [expectation fulfill];
      }];
  [self waitForExpectationsWithTimeout:0.1 handler:nil];

  [keyProviderClassMock verify];
  [keyProviderClassMock stopMocking];
  [componentsClassMock verify];
  [componentsClassMock stopMocking];
}

- (void)testShortenURLReturnsErrorWhenAPIKeyMissing {
  NSString *shortURLString = @"https://xyz.page.link/abcd";

  // Mock key provider
  id keyProviderClassMock = OCMClassMock([FIRDynamicLinkComponentsKeyProvider class]);
  [[[keyProviderClassMock expect] andReturn:nil] APIKey];

  id componentsClassMock = OCMClassMock([FIRDynamicLinkComponents class]);
  [[componentsClassMock stub]
      sendHTTPRequest:OCMOCK_ANY
           completion:[OCMArg checkWithBlock:^BOOL(id obj) {
             void (^completion)(NSData *_Nullable, NSError *_Nullable) = obj;
             NSDictionary *JSON = @{@"shortLink" : shortURLString};
             NSData *JSONData = [NSJSONSerialization dataWithJSONObject:JSON options:0 error:0];
             completion(JSONData, nil);
             return YES;
           }]];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"completion called with error"];
  NSURL *link = [NSURL URLWithString:@"https://google.com/abc"];
  FIRDynamicLinkComponents *components =
      [FIRDynamicLinkComponents componentsWithLink:link domainURIPrefix:kFDLURLDomain];
  [components
      shortenWithCompletion:^(NSURL *_Nullable shortURL, NSArray<NSString *> *_Nullable warnings,
                              NSError *_Nullable error) {
        XCTAssertNil(shortURL);
        if (error) {
          [expectation fulfill];
        }
      }];
  [self waitForExpectationsWithTimeout:0.1 handler:nil];

  [keyProviderClassMock verify];
  [keyProviderClassMock stopMocking];
  [componentsClassMock verify];
  [componentsClassMock stopMocking];
}

- (void)testShortenURLReturnsErrorWhenDomainIsMalformed {
  NSString *shortURLString = @"https://xyz.page.link/abcd";

  // Mock key provider
  id keyProviderClassMock = OCMClassMock([FIRDynamicLinkComponentsKeyProvider class]);
  [[keyProviderClassMock reject] APIKey];

  id componentsClassMock = OCMClassMock([FIRDynamicLinkComponents class]);
  [[componentsClassMock reject]
      sendHTTPRequest:OCMOCK_ANY
           completion:[OCMArg checkWithBlock:^BOOL(id obj) {
             void (^completion)(NSData *_Nullable, NSError *_Nullable) = obj;
             NSDictionary *JSON = @{@"shortLink" : shortURLString};
             NSData *JSONData = [NSJSONSerialization dataWithJSONObject:JSON options:0 error:0];
             completion(JSONData, nil);
             return YES;
           }]];

  NSURL *link = [NSURL URLWithString:@"https://google.com/abc"];
  FIRDynamicLinkComponents *components =
      [FIRDynamicLinkComponents componentsWithLink:link
                                   domainURIPrefix:@"this is invalid domain URI Prefix"];
  XCTAssertNil(components);

  [keyProviderClassMock verify];
  [keyProviderClassMock stopMocking];
  [componentsClassMock verify];
  [componentsClassMock stopMocking];
}

@end
