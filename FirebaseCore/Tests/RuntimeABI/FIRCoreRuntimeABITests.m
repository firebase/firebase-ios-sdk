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

// Checks FirebaseCore's Objective-C runtime contract: the classes, selectors, type encodings
// and protocol conformances that other code depends on at runtime. That includes the public API,
// the internal API declared in FirebaseCore/Extension, and selectors that closed-source binaries
// (FirebaseAnalytics), firebase-cpp-sdk, react-native-firebase, FlutterFire and other products'
// tests call or look up by name.
//
// Header-based API checks can't see this contract, and it must not change when FirebaseCore is
// reimplemented in Swift. The expected encodings are recorded from the Objective-C
// implementation in FIRCoreRuntimeABIGolden.m. To regenerate them after an approved change, run
// this test with FIR_RECORD_RUNTIME_ABI_GOLDEN=<output path> and replace the dictionary in that
// file with the output.

#import <XCTest/XCTest.h>

#import <objc/runtime.h>

#import "FirebaseCore/Tests/RuntimeABI/FIRCoreRuntimeABIGolden.h"

/// Class name -> selectors that must exist. Class methods start with "+", instance methods
/// with "-".
static NSDictionary<NSString *, NSArray<NSString *> *> *FIRCoreRuntimeABIContract(void) {
  NSMutableDictionary<NSString *, NSArray<NSString *> *> *contract = [@{
    @"FIRApp" : @[
      // Public.
      @"+configure", @"+configureWithOptions:", @"+configureWithName:options:", @"+defaultApp",
      @"+appNamed:", @"+allApps", @"-deleteApp:", @"-name", @"-options",
      @"-isDataCollectionDefaultEnabled", @"-setDataCollectionDefaultEnabled:",
      // Internal (FIRAppInternal.h). Called by other products, the FirebaseAnalytics binary,
      // firebase-cpp-sdk, react-native-firebase and FlutterFire.
      @"+isDefaultAppConfigured", @"+registerLibrary:withVersion:",
      @"+registerInternalLibrary:withName:", @"+registerInternalLibrary:withName:withVersion:",
      @"+firebaseUserAgent", @"+resetApps", @"-initInstanceWithName:options:", @"-isDefaultApp",
      @"-container", @"-setContainer:", @"-heartbeatLogger"
    ],
    @"FIROptions" : @[
      // Public.
      @"+defaultOptions", @"-initWithContentsOfFile:", @"-initWithGoogleAppID:GCMSenderID:",
      @"-APIKey", @"-setAPIKey:", @"-bundleID", @"-setBundleID:", @"-clientID",
      @"-setClientID:", @"-GCMSenderID", @"-setGCMSenderID:", @"-projectID",
      @"-setProjectID:", @"-googleAppID", @"-setGoogleAppID:", @"-databaseURL",
      @"-setDatabaseURL:", @"-storageBucket", @"-setStorageBucket:", @"-appGroupID",
      @"-setAppGroupID:", @"-copyWithZone:", @"-isEqual:", @"-hash",
      // Internal. The FirebaseAnalytics binary and GoogleAppMeasurement read the analytics
      // flags; other products' tests stub or call the rest.
      @"+defaultOptionsDictionary", @"+resetDefaultOptions", @"+plistFilePathWithName:",
      @"-initInternalWithOptionsDictionary:", @"-isAnalyticsCollectionExplicitlySet",
      @"-isAnalyticsCollectionEnabled", @"-isAnalyticsCollectionDeactivated", @"-libraryVersionID",
      @"-isEditingLocked", @"-setEditingLocked:",
      // Used by FirebaseCore's Swift unit tests through FirebaseCoreTestHooks.
      @"-analyticsOptionsDictionaryWithInfoDictionary:", @"-isMeasurementEnabled",
      @"-usingOptionsFromDefaultPlist", @"-setUsingOptionsFromDefaultPlist:"
    ],
    // Test seam used by FirebaseCoreTestHooks.
    @"FIRBundleUtil" : @[ @"+relevantBundles", @"+setRelevantBundlesForTesting:" ],
    @"FIRConfiguration" : @[
      @"+sharedInstance", @"-setLoggerLevel:", @"-loggerLevel", @"-analyticsConfiguration",
      @"-setAnalyticsConfiguration:"
    ],
    // Found by name by GoogleAppMeasurement.
    @"FIRAnalyticsConfiguration" :
        @[ @"+sharedInstance", @"-setAnalyticsCollectionEnabled:persistSetting:" ],
    @"FIRTimestamp" : @[
      @"+timestamp", @"+timestampWithDate:", @"+timestampWithSeconds:nanoseconds:",
      @"-initWithSeconds:nanoseconds:", @"-dateValue", @"-compare:", @"-seconds", @"-nanoseconds",
      @"-copyWithZone:", @"-isEqual:", @"-hash"
    ],
    @"FIRComponent" : @[
      @"+componentWithProtocol:creationBlock:",
      @"+componentWithProtocol:instantiationTiming:creationBlock:", @"-protocol",
      @"-instantiationTiming", @"-creationBlock"
    ],
    @"FIRComponentContainer" : @[
      @"-app", @"-__instanceForProtocol:", @"-instanceForProtocol:", @"-initWithApp:",
      @"-initWithApp:registrants:", @"-instantiateEagerComponents", @"-removeAllCachedInstances",
      @"-removeAllComponents", @"+registerAsComponentRegistrant:",
      @"+registerAsComponentRegistrant:inSet:", @"-components", @"-setComponents:"
    ],
    @"FIRComponentType" : @[ @"+instanceForProtocol:inContainer:" ],
    @"FIRHeartbeatLogger" : @[
      @"-initWithAppID:", @"-log", @"-headerValue",
      @"-asyncHeaderValueWithCompletionHandler:", @"-flushHeartbeatsIntoPayload",
      @"-flushHeartbeatsIntoPayloadWithCompletionHandler:", @"-heartbeatCodeForToday"
    ],
    @"FIRHeartbeatsPayload" : @[ @"-headerValue", @"-isEmpty" ],
  } mutableCopy];
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
  contract[@"FIRSceneFinder"] = @[
    @"+findForegroundSceneForApplication:matchingPredicate:",
    @"+findForegroundSceneForApplication:matchingSelector:",
    @"+findForegroundWindowSceneForApplication:"
  ];
#endif
  return contract;
}

/// Class name -> protocols the class must conform to.
static NSDictionary<NSString *, NSArray<NSString *> *> *FIRCoreRuntimeProtocolContract(void) {
  return @{
    @"FIROptions" : @[ @"NSCopying" ],
    @"FIRTimestamp" : @[ @"NSCopying" ],
    @"FIRHeartbeatLogger" : @[ @"FIRHeartbeatLoggerProtocol" ],
  };
}

/// Returns the type encoding without stack offsets, or nil if the method doesn't exist.
///
/// `BOOL` is encoded as `B` on arm64 and as `c` (signed char) on x86_64, so `c` is normalized to
/// `B`. None of the methods in the contract take or return a plain `char`.
static NSString *_Nullable FIRCoreMethodEncoding(Class klass, NSString *selectorKey) {
  BOOL isClassMethod = [selectorKey hasPrefix:@"+"];
  SEL selector = NSSelectorFromString([selectorKey substringFromIndex:1]);
  Method method = isClassMethod ? class_getClassMethod(klass, selector)
                                : class_getInstanceMethod(klass, selector);
  const char *typeEncoding = method ? method_getTypeEncoding(method) : NULL;
  if (!typeEncoding) {
    return nil;
  }
  NSString *encoding = @(typeEncoding);
  NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
  encoding = [[encoding componentsSeparatedByCharactersInSet:digits] componentsJoinedByString:@""];
  return [encoding stringByReplacingOccurrencesOfString:@"c" withString:@"B"];
}

@interface FIRCoreRuntimeABITests : XCTestCase
@end

@implementation FIRCoreRuntimeABITests

- (void)testRuntimeContractMatchesGolden {
  NSDictionary<NSString *, NSArray<NSString *> *> *contract = FIRCoreRuntimeABIContract();
  NSMutableDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *actual =
      [NSMutableDictionary dictionary];
  for (NSString *className in contract) {
    Class klass = NSClassFromString(className);
    XCTAssertNotNil(klass, @"Class %@ no longer exists.", className);
    if (!klass) {
      continue;
    }
    NSMutableDictionary<NSString *, NSString *> *methods = [NSMutableDictionary dictionary];
    for (NSString *selectorKey in contract[className]) {
      NSString *encoding = FIRCoreMethodEncoding(klass, selectorKey);
      XCTAssertNotNil(encoding, @"%@ no longer responds to %@.", className, selectorKey);
      if (encoding) {
        methods[selectorKey] = encoding;
      }
    }
    actual[className] = methods;
  }

  const char *recordPath = getenv("FIR_RECORD_RUNTIME_ABI_GOLDEN");
  if (recordPath) {
    NSData *data =
        [NSJSONSerialization dataWithJSONObject:actual
                                        options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                          error:nil];
    [data writeToFile:@(recordPath) atomically:YES];
    return;
  }

  NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *golden =
      FIRCoreRuntimeABIGolden();
  for (NSString *className in actual) {
    for (NSString *selectorKey in actual[className]) {
      NSString *expected = golden[className][selectorKey];
      // Selectors that only exist on some platforms aren't in the golden file.
      if (!expected) {
        continue;
      }
      XCTAssertEqualObjects(actual[className][selectorKey], expected,
                            @"Type encoding of %@ %@ changed.", className, selectorKey);
    }
  }
}

- (void)testProtocolConformances {
  NSDictionary<NSString *, NSArray<NSString *> *> *contract = FIRCoreRuntimeProtocolContract();
  for (NSString *className in contract) {
    Class klass = NSClassFromString(className);
    XCTAssertNotNil(klass, @"Class %@ no longer exists.", className);
    for (NSString *protocolName in contract[className]) {
      Protocol *protocol = NSProtocolFromString(protocolName);
      XCTAssertNotNil(protocol, @"Protocol %@ no longer exists.", protocolName);
      XCTAssertTrue(class_conformsToProtocol(klass, protocol), @"%@ no longer conforms to %@.",
                    className, protocolName);
    }
  }
}

- (void)testFIRLibraryProtocolExists {
  XCTAssertNotNil(NSProtocolFromString(@"FIRLibrary"));
  XCTAssertNotNil(NSProtocolFromString(@"FIRComponentLifecycleMaintainer"));
}

@end
