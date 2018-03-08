// Copyright 2017 Google
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

#import "FIRTestCase.h"

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRBundleUtil.h>
#import <FirebaseCore/FIROptionsInternal.h>

extern NSString *const kFIRIsMeasurementEnabled;
extern NSString *const kFIRIsAnalyticsCollectionEnabled;
extern NSString *const kFIRIsAnalyticsCollectionDeactivated;
extern NSString *const kFIRLibraryVersionID;

@interface FIROptions (Test)

- (nullable NSDictionary *)analyticsOptionsDictionaryWithInfoDictionary:
    (nullable NSDictionary *)infoDictionary;

@end

@interface FIROptionsTest : FIRTestCase

@end

@implementation FIROptionsTest

- (void)setUp {
  [super setUp];
  [FIROptions resetDefaultOptions];
}

- (void)testInit {
  NSDictionary *optionsDictionary = [FIROptions defaultOptionsDictionary];
  FIROptions *options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  [self assertOptionsMatchDefaults:options andProjectID:YES];
  XCTAssertNil(options.deepLinkURLScheme);
  XCTAssertTrue(options.usingOptionsFromDefaultPlist);

  options.deepLinkURLScheme = kDeepLinkURLScheme;
  XCTAssertEqualObjects(options.deepLinkURLScheme, kDeepLinkURLScheme);
}

- (void)testDefaultOptionsDictionaryWithNilFilePath {
  id mockBundleUtil = OCMClassMock([FIRBundleUtil class]);
  [OCMStub([mockBundleUtil optionsDictionaryPathWithResourceName:kServiceInfoFileName
                                                     andFileType:kServiceInfoFileType
                                                       inBundles:[FIRBundleUtil relevantBundles]])
      andReturn:nil];
  XCTAssertNil([FIROptions defaultOptionsDictionary]);
}

- (void)testDefaultOptionsDictionaryWithInvalidSourceFile {
  id mockBundleUtil = OCMClassMock([FIRBundleUtil class]);
  [OCMStub([mockBundleUtil optionsDictionaryPathWithResourceName:kServiceInfoFileName
                                                     andFileType:kServiceInfoFileType
                                                       inBundles:[FIRBundleUtil relevantBundles]])
      andReturn:@"invalid.plist"];
  XCTAssertNil([FIROptions defaultOptionsDictionary]);
}

- (void)testDefaultOptions {
  FIROptions *options = [FIROptions defaultOptions];
  [self assertOptionsMatchDefaults:options andProjectID:YES];
  XCTAssertNil(options.deepLinkURLScheme);
  XCTAssertTrue(options.usingOptionsFromDefaultPlist);

  options.deepLinkURLScheme = kDeepLinkURLScheme;
  XCTAssertEqualObjects(options.deepLinkURLScheme, kDeepLinkURLScheme);
}

- (void)testInitCustomizedOptions {
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                       bundleID:kBundleID
                                                    GCMSenderID:kGCMSenderID
                                                         APIKey:kAPIKey
                                                       clientID:kClientID
                                                     trackingID:kTrackingID
                                                androidClientID:(id _Nonnull)nil
                                                    databaseURL:kDatabaseURL
                                                  storageBucket:kStorageBucket
                                              deepLinkURLScheme:kDeepLinkURLScheme];
#pragma clang pop
  [self assertOptionsMatchDefaults:options andProjectID:NO];
  XCTAssertEqualObjects(options.deepLinkURLScheme, kDeepLinkURLScheme);
  XCTAssertFalse(options.usingOptionsFromDefaultPlist);

  FIROptions *options2 =
      [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID GCMSenderID:kGCMSenderID];
  options2.APIKey = kAPIKey;
  options2.bundleID = kBundleID;
  options2.clientID = kClientID;
  options2.databaseURL = kDatabaseURL;
  options2.deepLinkURLScheme = kDeepLinkURLScheme;
  options2.projectID = kProjectID;
  options2.storageBucket = kStorageBucket;
  options2.trackingID = kTrackingID;
  [self assertOptionsMatchDefaults:options2 andProjectID:YES];
  XCTAssertEqualObjects(options2.deepLinkURLScheme, kDeepLinkURLScheme);
  XCTAssertFalse(options.usingOptionsFromDefaultPlist);

// nil GoogleAppID should throw an exception
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  XCTAssertThrows([[FIROptions alloc] initWithGoogleAppID:nil
                                                 bundleID:kBundleID
                                              GCMSenderID:kGCMSenderID
                                                   APIKey:kCustomizedAPIKey
                                                 clientID:nil
                                               trackingID:nil
                                          androidClientID:nil
                                              databaseURL:nil
                                            storageBucket:nil
                                        deepLinkURLScheme:nil]);
#pragma clang diagnostic pop
}

- (void)testInitWithContentsOfFile {
  NSString *filePath =
      [[NSBundle mainBundle] pathForResource:@"GoogleService-Info" ofType:@"plist"];
  FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:filePath];
  [self assertOptionsMatchDefaults:options andProjectID:YES];
  XCTAssertNil(options.deepLinkURLScheme);
  XCTAssertFalse(options.usingOptionsFromDefaultPlist);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  FIROptions *emptyOptions = [[FIROptions alloc] initWithContentsOfFile:nil];
#pragma clang diagnostic pop
  XCTAssertNil(emptyOptions);

  FIROptions *invalidOptions = [[FIROptions alloc] initWithContentsOfFile:@"invalid.plist"];
  XCTAssertNil(invalidOptions);
}

- (void)assertOptionsMatchDefaults:(FIROptions *)options andProjectID:(BOOL)matchProjectID {
  XCTAssertEqualObjects(options.googleAppID, kGoogleAppID);
  XCTAssertEqualObjects(options.APIKey, kAPIKey);
  XCTAssertEqualObjects(options.clientID, kClientID);
  XCTAssertEqualObjects(options.trackingID, kTrackingID);
  XCTAssertEqualObjects(options.GCMSenderID, kGCMSenderID);
  XCTAssertNil(options.androidClientID);
  XCTAssertEqualObjects(options.libraryVersionID, kFIRLibraryVersionID);
  XCTAssertEqualObjects(options.databaseURL, kDatabaseURL);
  XCTAssertEqualObjects(options.storageBucket, kStorageBucket);
  XCTAssertEqualObjects(options.bundleID, kBundleID);

  // Custom `matchProjectID` parameter to be removed once the deprecated `FIROptions` constructor is
  // removed.
  if (matchProjectID) {
    XCTAssertEqualObjects(options.projectID, kProjectID);
  }
}

- (void)testCopyingProperties {
  NSMutableString *mutableString;
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID GCMSenderID:kGCMSenderID];
  mutableString = [[NSMutableString alloc] initWithString:@"1"];
  options.APIKey = mutableString;
  [mutableString appendString:@"2"];
  XCTAssertEqualObjects(options.APIKey, @"1");

  mutableString = [[NSMutableString alloc] initWithString:@"1"];
  options.bundleID = mutableString;
  [mutableString appendString:@"2"];
  XCTAssertEqualObjects(options.bundleID, @"1");

  mutableString = [[NSMutableString alloc] initWithString:@"1"];
  options.clientID = mutableString;
  [mutableString appendString:@"2"];
  XCTAssertEqualObjects(options.clientID, @"1");

  mutableString = [[NSMutableString alloc] initWithString:@"1"];
  options.trackingID = mutableString;
  [mutableString appendString:@"2"];
  XCTAssertEqualObjects(options.trackingID, @"1");

  mutableString = [[NSMutableString alloc] initWithString:@"1"];
  options.GCMSenderID = mutableString;
  [mutableString appendString:@"2"];
  XCTAssertEqualObjects(options.GCMSenderID, @"1");

  mutableString = [[NSMutableString alloc] initWithString:@"1"];
  options.projectID = mutableString;
  [mutableString appendString:@"2"];
  XCTAssertEqualObjects(options.projectID, @"1");

  mutableString = [[NSMutableString alloc] initWithString:@"1"];
  options.androidClientID = mutableString;
  [mutableString appendString:@"2"];
  XCTAssertEqualObjects(options.androidClientID, @"1");

  mutableString = [[NSMutableString alloc] initWithString:@"1"];
  options.googleAppID = mutableString;
  [mutableString appendString:@"2"];
  XCTAssertEqualObjects(options.googleAppID, @"1");

  mutableString = [[NSMutableString alloc] initWithString:@"1"];
  options.databaseURL = mutableString;
  [mutableString appendString:@"2"];
  XCTAssertEqualObjects(options.databaseURL, @"1");

  mutableString = [[NSMutableString alloc] initWithString:@"1"];
  options.deepLinkURLScheme = mutableString;
  [mutableString appendString:@"2"];
  XCTAssertEqualObjects(options.deepLinkURLScheme, @"1");

  mutableString = [[NSMutableString alloc] initWithString:@"1"];
  options.storageBucket = mutableString;
  [mutableString appendString:@"2"];
  XCTAssertEqualObjects(options.storageBucket, @"1");
}

- (void)testCopyWithZone {
  // default options
  FIROptions *options = [FIROptions defaultOptions];
  options.deepLinkURLScheme = kDeepLinkURLScheme;
  XCTAssertEqualObjects(options.deepLinkURLScheme, kDeepLinkURLScheme);

  FIROptions *newOptions = [options copy];
  XCTAssertEqualObjects(newOptions.deepLinkURLScheme, kDeepLinkURLScheme);

  [options setDeepLinkURLScheme:kNewDeepLinkURLScheme];
  XCTAssertEqualObjects(options.deepLinkURLScheme, kNewDeepLinkURLScheme);
  XCTAssertEqualObjects(newOptions.deepLinkURLScheme, kDeepLinkURLScheme);

  // customized options
  FIROptions *customizedOptions = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                                 bundleID:kBundleID
                                                              GCMSenderID:kGCMSenderID
                                                                   APIKey:kAPIKey
                                                                 clientID:kClientID
                                                               trackingID:kTrackingID
                                                          androidClientID:(id _Nonnull)nil
                                                              databaseURL:kDatabaseURL
                                                            storageBucket:kStorageBucket
                                                        deepLinkURLScheme:kDeepLinkURLScheme];
  FIROptions *copyCustomizedOptions = [customizedOptions copy];
  [copyCustomizedOptions setDeepLinkURLScheme:kNewDeepLinkURLScheme];
  XCTAssertEqualObjects(customizedOptions.deepLinkURLScheme, kDeepLinkURLScheme);
  XCTAssertEqualObjects(copyCustomizedOptions.deepLinkURLScheme, kNewDeepLinkURLScheme);
}

- (void)testAnalyticsConstants {
  // The keys are public values and should never change.
  XCTAssertEqualObjects(kFIRIsMeasurementEnabled, @"IS_MEASUREMENT_ENABLED");
  XCTAssertEqualObjects(kFIRIsAnalyticsCollectionEnabled, @"FIREBASE_ANALYTICS_COLLECTION_ENABLED");
  XCTAssertEqualObjects(kFIRIsAnalyticsCollectionDeactivated,
                        @"FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED");
}

- (void)testAnalyticsOptions {
  // No keys anywhere.
  NSDictionary *optionsDictionary = nil;
  FIROptions *options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  NSDictionary *mainDictionary = nil;
  NSDictionary *expectedAnalyticsOptions = @{};
  NSDictionary *analyticsOptions = [options analyticsOptionsDictionaryWithInfoDictionary:nil];
  XCTAssertEqualObjects(analyticsOptions, expectedAnalyticsOptions);

  optionsDictionary = @{};
  options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  mainDictionary = @{};
  expectedAnalyticsOptions = @{};
  analyticsOptions = [options analyticsOptionsDictionaryWithInfoDictionary:mainDictionary];
  XCTAssertEqualObjects(analyticsOptions, expectedAnalyticsOptions);

  // Main has no keys.
  optionsDictionary = @{
    kFIRIsAnalyticsCollectionDeactivated : @YES,
    kFIRIsAnalyticsCollectionEnabled : @YES,
    kFIRIsMeasurementEnabled : @YES
  };
  options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  mainDictionary = @{};
  expectedAnalyticsOptions = optionsDictionary;
  analyticsOptions = [options analyticsOptionsDictionaryWithInfoDictionary:mainDictionary];
  XCTAssertEqualObjects(analyticsOptions, expectedAnalyticsOptions);

  // Main overrides all the keys.
  optionsDictionary = @{
    kFIRIsAnalyticsCollectionDeactivated : @YES,
    kFIRIsAnalyticsCollectionEnabled : @YES,
    kFIRIsMeasurementEnabled : @YES
  };
  options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  mainDictionary = @{
    kFIRIsAnalyticsCollectionDeactivated : @NO,
    kFIRIsAnalyticsCollectionEnabled : @NO,
    kFIRIsMeasurementEnabled : @NO
  };
  expectedAnalyticsOptions = mainDictionary;
  analyticsOptions = [options analyticsOptionsDictionaryWithInfoDictionary:mainDictionary];
  XCTAssertEqualObjects(analyticsOptions, expectedAnalyticsOptions);

  // Keys exist only in main.
  optionsDictionary = @{};
  options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  mainDictionary = @{
    kFIRIsAnalyticsCollectionDeactivated : @YES,
    kFIRIsAnalyticsCollectionEnabled : @YES,
    kFIRIsMeasurementEnabled : @YES
  };
  expectedAnalyticsOptions = mainDictionary;
  analyticsOptions = [options analyticsOptionsDictionaryWithInfoDictionary:mainDictionary];
  XCTAssertEqualObjects(analyticsOptions, expectedAnalyticsOptions);

  // Main overrides single keys.
  optionsDictionary = @{
    kFIRIsAnalyticsCollectionDeactivated : @YES,
    kFIRIsAnalyticsCollectionEnabled : @YES,
    kFIRIsMeasurementEnabled : @YES
  };
  options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  mainDictionary = @{ kFIRIsAnalyticsCollectionDeactivated : @NO };
  expectedAnalyticsOptions = @{
    kFIRIsAnalyticsCollectionDeactivated : @NO,  // override
    kFIRIsAnalyticsCollectionEnabled : @YES,
    kFIRIsMeasurementEnabled : @YES
  };
  analyticsOptions = [options analyticsOptionsDictionaryWithInfoDictionary:mainDictionary];
  XCTAssertEqualObjects(analyticsOptions, expectedAnalyticsOptions);

  optionsDictionary = @{
    kFIRIsAnalyticsCollectionDeactivated : @YES,
    kFIRIsAnalyticsCollectionEnabled : @YES,
    kFIRIsMeasurementEnabled : @YES
  };
  options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  mainDictionary = @{ kFIRIsAnalyticsCollectionEnabled : @NO };
  expectedAnalyticsOptions = @{
    kFIRIsAnalyticsCollectionDeactivated : @YES,
    kFIRIsAnalyticsCollectionEnabled : @NO,  // override
    kFIRIsMeasurementEnabled : @YES
  };
  analyticsOptions = [options analyticsOptionsDictionaryWithInfoDictionary:mainDictionary];
  XCTAssertEqualObjects(analyticsOptions, expectedAnalyticsOptions);

  optionsDictionary = @{
    kFIRIsAnalyticsCollectionDeactivated : @YES,
    kFIRIsAnalyticsCollectionEnabled : @YES,
    kFIRIsMeasurementEnabled : @YES
  };
  options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  mainDictionary = @{ kFIRIsMeasurementEnabled : @NO };
  expectedAnalyticsOptions = @{
    kFIRIsAnalyticsCollectionDeactivated : @YES,
    kFIRIsAnalyticsCollectionEnabled : @YES,
    kFIRIsMeasurementEnabled : @NO  // override
  };
  analyticsOptions = [options analyticsOptionsDictionaryWithInfoDictionary:mainDictionary];
  XCTAssertEqualObjects(analyticsOptions, expectedAnalyticsOptions);
}

- (void)testAnalyticsOptions_combinatorial {
  // Complete combinatorial test.

  // Possible values for the flags in the plist, where NSNull means the flag is not present.
  NSArray *values = @[ [NSNull null], @NO, @YES ];

  // Sanity checks for the combination generation.
  int combinationCount = 0;
  NSMutableArray *uniqueMainCombinations = [[NSMutableArray alloc] init];
  NSMutableArray *uniqueOptionsCombinations = [[NSMutableArray alloc] init];

  // Generate all optout flag combinations for { main plist X GoogleService-info options plist }.
  // Options present in the main plist should override options of the same key in the service plist.
  for (id mainDeactivated in values) {
    for (id mainAnalyticsEnabled in values) {
      for (id mainMeasurementEnabled in values) {
        for (id optionsDeactivated in values) {
          for (id optionsAnalyticsEnabled in values) {
            for (id optionsMeasurementEnabled in values) {
              @autoreleasepool {
                // Fill the GoogleService-info options plist dictionary.
                NSMutableDictionary *optionsDictionary = [[NSMutableDictionary alloc] init];
                if (![optionsDeactivated isEqual:[NSNull null]]) {
                  optionsDictionary[kFIRIsAnalyticsCollectionDeactivated] = optionsDeactivated;
                }
                if (![optionsAnalyticsEnabled isEqual:[NSNull null]]) {
                  optionsDictionary[kFIRIsAnalyticsCollectionEnabled] = optionsAnalyticsEnabled;
                }
                if (![optionsMeasurementEnabled isEqual:[NSNull null]]) {
                  optionsDictionary[kFIRIsMeasurementEnabled] = optionsMeasurementEnabled;
                }

                FIROptions *options =
                    [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
                if (![uniqueOptionsCombinations containsObject:optionsDictionary]) {
                  [uniqueOptionsCombinations addObject:optionsDictionary];
                }

                // Fill the main plist dictionary.
                NSMutableDictionary *mainDictionary = [[NSMutableDictionary alloc] init];
                if (![mainDeactivated isEqual:[NSNull null]]) {
                  mainDictionary[kFIRIsAnalyticsCollectionDeactivated] = mainDeactivated;
                }
                if (![mainAnalyticsEnabled isEqual:[NSNull null]]) {
                  mainDictionary[kFIRIsAnalyticsCollectionEnabled] = mainAnalyticsEnabled;
                }
                if (![mainMeasurementEnabled isEqual:[NSNull null]]) {
                  mainDictionary[kFIRIsMeasurementEnabled] = mainMeasurementEnabled;
                }

                // Add mainDictionary to uniqueMainCombinations if it isn't included yet.
                if (![uniqueMainCombinations containsObject:mainDictionary]) {
                  [uniqueMainCombinations addObject:mainDictionary];
                }

                // Generate the expected options by adding main values on top of the service options
                // values. The main values will replace any existing options values with the same
                // key. This is a different way of combining the two sets of flags from the actual
                // implementation in FIROptions, with equivalent output.
                NSMutableDictionary *expectedAnalyticsOptions =
                    [[NSMutableDictionary alloc] initWithDictionary:optionsDictionary];
                [expectedAnalyticsOptions addEntriesFromDictionary:mainDictionary];

                NSDictionary *analyticsOptions =
                    [options analyticsOptionsDictionaryWithInfoDictionary:mainDictionary];
                XCTAssertEqualObjects(analyticsOptions, expectedAnalyticsOptions);

                combinationCount++;
              }
            }
          }
        }
      }
    }
  }

  // Verify the sanity checks.
  XCTAssertEqual(combinationCount, 729);  // = 3^6.

  XCTAssertEqual(uniqueOptionsCombinations.count, 27);
  int optionsSizeCount[4] = {0};
  for (NSDictionary *dictionary in uniqueOptionsCombinations) {
    optionsSizeCount[dictionary.count]++;
  }
  XCTAssertEqual(optionsSizeCount[0], 1);
  XCTAssertEqual(optionsSizeCount[1], 6);
  XCTAssertEqual(optionsSizeCount[2], 12);
  XCTAssertEqual(optionsSizeCount[3], 8);

  XCTAssertEqual(uniqueMainCombinations.count, 27);
  int mainSizeCount[4] = {0};
  for (NSDictionary *dictionary in uniqueMainCombinations) {
    mainSizeCount[dictionary.count]++;
  }
  XCTAssertEqual(mainSizeCount[0], 1);
  XCTAssertEqual(mainSizeCount[1], 6);
  XCTAssertEqual(mainSizeCount[2], 12);
  XCTAssertEqual(mainSizeCount[3], 8);
}

- (void)testVersionFormat {
  NSRegularExpression *sLibraryVersionRegex =
      [NSRegularExpression regularExpressionWithPattern:@"^[0-9]{8,}$" options:0 error:NULL];
  NSUInteger numberOfMatches =
      [sLibraryVersionRegex numberOfMatchesInString:kFIRLibraryVersionID
                                            options:0
                                              range:NSMakeRange(0, kFIRLibraryVersionID.length)];
  XCTAssertEqual(numberOfMatches, 1, @"Incorrect library version format.");
}

@end
