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

#import "FirebaseCore/Tests/RuntimeABI/FIRCoreRuntimeABIGolden.h"

// Recorded on macOS from the Objective-C implementation of FirebaseCore (Firebase 13.3.0).
// See FIRCoreRuntimeABITests.m to regenerate.
NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *FIRCoreRuntimeABIGolden(void) {
  // clang-format off
  return @{
    @"FIRAnalyticsConfiguration" : @{
      @"+setUserDefaultsForTesting:" : @"v@:@",
      @"+sharedInstance" : @"@@:",
      @"-setAnalyticsCollectionEnabled:persistSetting:" : @"v@:BB",
    },
    @"FIRApp" : @{
      @"+allApps" : @"@@:",
      @"+appNamed:" : @"@@:@",
      @"+configure" : @"v@:",
      @"+configureWithName:options:" : @"v@:@@",
      @"+configureWithOptions:" : @"v@:@",
      @"+defaultApp" : @"@@:",
      @"+firebaseUserAgent" : @"@@:",
      @"+isDefaultAppConfigured" : @"B@:",
      @"+registerInternalLibrary:withName:" : @"v@:#@",
      @"+registerInternalLibrary:withName:withVersion:" : @"v@:#@@",
      @"+registerLibrary:withVersion:" : @"v@:@@",
      @"+resetApps" : @"v@:",
      @"+setHeartbeatLoggerFactoryForTesting:" : @"v@:@?",
      @"+setInfoDictionaryForTesting:" : @"v@:@",
      @"+setIsAppExtensionForTesting:" : @"v@:@",
      @"+setUserDefaultsForTesting:" : @"v@:@",
      @"+validateAppID:" : @"B@:@",
      @"+validateAppIDFormat:withVersion:" : @"B@:@@",
      @"+validateBundleIDHashWithinAppID:forVersion:" : @"B@:@@",
      @"-container" : @"@@:",
      @"-deleteApp:" : @"v@:@?",
      @"-heartbeatLogger" : @"@@:",
      @"-initInstanceWithName:options:" : @"@@:@@",
      @"-isAppIDValid" : @"B@:",
      @"-isDataCollectionDefaultEnabled" : @"B@:",
      @"-isDefaultApp" : @"B@:",
      @"-name" : @"@@:",
      @"-options" : @"@@:",
      @"-setContainer:" : @"v@:@",
      @"-setDataCollectionDefaultEnabled:" : @"v@:B",
    },
    @"FIRBundleUtil" : @{
      @"+hasBundleIdentifierPrefix:inBundles:" : @"B@:@@",
      @"+isAppExtension" : @"B@:",
      @"+optionsDictionaryPathWithResourceName:andFileType:inBundles:" : @"@@:@@@",
      @"+relevantBundles" : @"@@:",
      @"+relevantURLSchemes" : @"@@:",
      @"+setIsAppExtensionForTesting:" : @"v@:@",
      @"+setRelevantBundlesForTesting:" : @"v@:@",
    },
    @"FIRComponent" : @{
      @"+componentWithProtocol:creationBlock:" : @"@@:@@?",
      @"+componentWithProtocol:instantiationTiming:creationBlock:" : @"@@:@q@?",
      @"-creationBlock" : @"@?@:",
      @"-instantiationTiming" : @"q@:",
      @"-protocol" : @"@@:",
    },
    @"FIRComponentContainer" : @{
      @"+registerAsComponentRegistrant:" : @"v@:#",
      @"+registerAsComponentRegistrant:inSet:" : @"v@:#@",
      @"-__instanceForProtocol:" : @"@@:@",
      @"-app" : @"@@:",
      @"-components" : @"@@:",
      @"-initWithApp:" : @"@@:@",
      @"-initWithApp:registrants:" : @"@@:@@",
      @"-instanceForProtocol:" : @"@@:@",
      @"-instantiateEagerComponents" : @"v@:",
      @"-removeAllCachedInstances" : @"v@:",
      @"-removeAllComponents" : @"v@:",
      @"-setComponents:" : @"v@:@",
    },
    @"FIRComponentType" : @{
      @"+instanceForProtocol:inContainer:" : @"@@:@@",
    },
    @"FIRConfiguration" : @{
      @"+sharedInstance" : @"@@:",
      @"-analyticsConfiguration" : @"@@:",
      @"-loggerLevel" : @"q@:",
      @"-setAnalyticsConfiguration:" : @"v@:@",
      @"-setLoggerLevel:" : @"v@:q",
    },
    @"FIRHeartbeatLogger" : @{
      @"-asyncHeaderValueWithCompletionHandler:" : @"v@:@?",
      @"-flushHeartbeatsIntoPayload" : @"@@:",
      @"-flushHeartbeatsIntoPayloadWithCompletionHandler:" : @"v@:@?",
      @"-headerValue" : @"@@:",
      @"-heartbeatCodeForToday" : @"q@:",
      @"-initWithAppID:" : @"@@:@",
      @"-initWithAppID:userAgentProvider:" : @"@@:@@?",
      @"-log" : @"v@:",
    },
    @"FIRHeartbeatsPayload" : @{
      @"-headerValue" : @"@@:",
      @"-isEmpty" : @"B@:",
    },
    @"FIROptions" : @{
      @"+defaultOptions" : @"@@:",
      @"+defaultOptionsDictionary" : @"@@:",
      @"+plistFilePathWithName:" : @"@@:@",
      @"+resetDefaultOptions" : @"v@:",
      @"-APIKey" : @"@@:",
      @"-GCMSenderID" : @"@@:",
      @"-analyticsOptionsDictionaryWithInfoDictionary:" : @"@@:@",
      @"-appGroupID" : @"@@:",
      @"-bundleID" : @"@@:",
      @"-clientID" : @"@@:",
      @"-copyWithZone:" : @"@@:^{_NSZone=}",
      @"-databaseURL" : @"@@:",
      @"-googleAppID" : @"@@:",
      @"-hash" : @"Q@:",
      @"-initInternalWithOptionsDictionary:" : @"@@:@",
      @"-initWithContentsOfFile:" : @"@@:@",
      @"-initWithGoogleAppID:GCMSenderID:" : @"@@:@@",
      @"-isAnalyticsCollectionDeactivated" : @"B@:",
      @"-isAnalyticsCollectionEnabled" : @"B@:",
      @"-isAnalyticsCollectionExplicitlySet" : @"B@:",
      @"-isEditingLocked" : @"B@:",
      @"-isEqual:" : @"B@:@",
      @"-isMeasurementEnabled" : @"B@:",
      @"-libraryVersionID" : @"@@:",
      @"-projectID" : @"@@:",
      @"-setAPIKey:" : @"v@:@",
      @"-setAppGroupID:" : @"v@:@",
      @"-setBundleID:" : @"v@:@",
      @"-setClientID:" : @"v@:@",
      @"-setDatabaseURL:" : @"v@:@",
      @"-setEditingLocked:" : @"v@:B",
      @"-setGCMSenderID:" : @"v@:@",
      @"-setGoogleAppID:" : @"v@:@",
      @"-setProjectID:" : @"v@:@",
      @"-setStorageBucket:" : @"v@:@",
      @"-setUsingOptionsFromDefaultPlist:" : @"v@:B",
      @"-storageBucket" : @"@@:",
      @"-usingOptionsFromDefaultPlist" : @"B@:",
    },
    @"FIRTimestamp" : @{
      @"+timestamp" : @"@@:",
      @"+timestampWithDate:" : @"@@:@",
      @"+timestampWithSeconds:nanoseconds:" : @"@@:qi",
      @"-compare:" : @"q@:@",
      @"-copyWithZone:" : @"@@:^{_NSZone=}",
      @"-dateValue" : @"@@:",
      @"-hash" : @"Q@:",
      @"-initWithSeconds:nanoseconds:" : @"@@:qi",
      @"-isEqual:" : @"B@:@",
      @"-nanoseconds" : @"i@:",
      @"-seconds" : @"q@:",
    },
  };
  // clang-format on
}
