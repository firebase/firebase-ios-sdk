/*
 * Copyright 2019 Google
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

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIROptionsInternal.h>
#import <FirebaseCoreDiagnosticsInterop/FIRCoreDiagnosticsData.h>
#import <FirebaseCoreDiagnosticsInterop/FIRCoreDiagnosticsInterop.h>
#import <GoogleDataTransport/GDTEventDataObject.h>
#import <GoogleDataTransportCCTSupport/GDTCCTPrioritizer.h>
#import <GoogleUtilities/GULUserDefaults.h>
#import <OCMock/OCMock.h>
#import <nanopb/pb_decode.h>
#import <nanopb/pb_encode.h>

#import "FIRCDLibrary/Protogen/nanopb/firebasecore.nanopb.h"

extern NSString *const kUniqueInstallFileName;

extern NSString *const kFIRAppDiagnosticsNotification;

extern NSString *const kFIRAppDiagnosticsConfigurationTypeKey;
extern NSString *const kFIRAppDiagnosticsErrorKey;
extern NSString *const kFIRAppDiagnosticsFIRAppKey;
extern NSString *const kFIRAppDiagnosticsSDKNameKey;
extern NSString *const kFIRAppDiagnosticsSDKVersionKey;

extern NSString *const kFIRLastCheckinDateKey;

NSString *const kGoogleAppID = @"1:123:ios:123abc";
NSString *const kBundleID = @"com.google.FirebaseSDKTests";
NSString *const kLibraryVersionID = @"1.2.3";

#pragma mark - Testing interfaces

@interface GULUserDefaults (ExposedForTests)
- (void)clearAllData;
@end

@interface FIRApp ()

- (BOOL)configureCore;
+ (NSError *)errorForInvalidAppID;
+ (NSError *)errorForMissingOptions;
- (BOOL)isAppIDValid;

@end

@interface FIRCoreDiagnostics : NSObject

// Install string helpers.
+ (NSString *)installString;
+ (BOOL)writeString:(NSString *)string toURL:(NSURL *)filePathURL;
+ (NSURL *)filePathURLWithName:(NSString *)fileName;
+ (NSString *)stringAtURL:(NSURL *)filePathURL;

// Metadata helpers.
+ (NSString *)deviceModel;

// nanopb helper functions.
extern pb_bytes_array_t *FIREncodeString(NSString *string);
extern pb_bytes_array_t *FIREncodeData(NSData *data);
extern logs_proto_mobilesdk_ios_ICoreConfiguration_ServiceType FIRMapFromServiceStringToTypeEnum(
    NSString *serviceString);

// Proto population functions.
extern void FIRPopulateProtoWithInfoFromUserInfoParams(
    logs_proto_mobilesdk_ios_ICoreConfiguration *config,
    NSDictionary<NSString *, id> *diagnosticObjects);
extern void FIRPopulateProtoWithCommonInfoFromApp(
    logs_proto_mobilesdk_ios_ICoreConfiguration *config,
    NSDictionary<NSString *, id> *diagnosticObjects);
extern void FIRPopulateProtoWithInstalledServices(
    logs_proto_mobilesdk_ios_ICoreConfiguration *config);
extern void FIRPopulateProtoWithNumberOfLinkedFrameworks(
    logs_proto_mobilesdk_ios_ICoreConfiguration *config);
extern void FIRPopulateProtoWithInfoPlistValues(
    logs_proto_mobilesdk_ios_ICoreConfiguration *config);

// FIRCoreDiagnosticsInterop.
+ (void)sendDiagnosticsData:(nonnull id<FIRCoreDiagnosticsData>)diagnosticsData;

@end

#pragma mark - Testing classes

@interface FIRCoreDiagnosticsTestData : NSObject <FIRCoreDiagnosticsData>

@end

@implementation FIRCoreDiagnosticsTestData

@synthesize diagnosticObjects = _diagnosticObjects;

- (instancetype)init {
  self = [super init];
  if (self) {
    _diagnosticObjects = @{
      kFIRCDGoogleAppIDKey : kGoogleAppID,
      kFIRBundleID : kFIRBundleID,
      kFIRCDllAppsCountKey : @1
    };
  }
  return self;
}

@end

@interface FIRCoreDiagnosticsLog : NSObject <GDTEventDataObject>

@property(nonatomic) logs_proto_mobilesdk_ios_ICoreConfiguration config;

- (instancetype)initWithConfig:(logs_proto_mobilesdk_ios_ICoreConfiguration)config;

@end

#pragma mark - Tests

@interface FIRCoreDiagnosticsTest : XCTestCase

@property(nonatomic) id optionsInstanceMock;
@property(nonatomic) NSDictionary<NSString *, id> *expectedUserInfo;

@end

@implementation FIRCoreDiagnosticsTest

- (void)setUp {
  [super setUp];
  [FIROptions resetDefaultOptions];
  [FIRApp resetApps];
}

- (void)tearDown {
  [super tearDown];
}

/** Tests initialization. */
- (void)testExternVariableIsSet {
  XCTAssertNotNil(FIRCoreDiagnosticsImplementation);
}

/** Tests populating the proto correctly. */
- (void)testProtoPopulation {
  logs_proto_mobilesdk_ios_ICoreConfiguration icoreConfiguration =
      logs_proto_mobilesdk_ios_ICoreConfiguration_init_default;
  FIRPopulateProtoWithCommonInfoFromApp(&icoreConfiguration, @{
    kFIRCDllAppsCountKey : @1,
    kFIRCDGoogleAppIDKey : kGoogleAppID,
    kFIRCDBundleIDKey : kBundleID,
    kFIRCDLibraryVersionIDKey : kLibraryVersionID,
    kFIRCDUsingOptionsFromDefaultPlistKey : @YES
  });
  FIRPopulateProtoWithNumberOfLinkedFrameworks(&icoreConfiguration);
  FIRPopulateProtoWithInfoPlistValues(&icoreConfiguration);
  icoreConfiguration.configuration_type =
      logs_proto_mobilesdk_ios_ICoreConfiguration_ConfigurationType_CORE;

  logs_proto_mobilesdk_ios_ICoreConfiguration icoreExpectedConfiguration =
      logs_proto_mobilesdk_ios_ICoreConfiguration_init_default;
  [self populateProto:&icoreExpectedConfiguration];

  FIRCoreDiagnosticsLog *log = [[FIRCoreDiagnosticsLog alloc] initWithConfig:icoreConfiguration];
  FIRCoreDiagnosticsLog *expectedLog =
      [[FIRCoreDiagnosticsLog alloc] initWithConfig:icoreExpectedConfiguration];

  XCTAssert([[log transportBytes] isEqualToData:[expectedLog transportBytes]]);
  // A pb_release here should not be necessary here, as FIRCoreDiagnosticsLog should do it.
}

- (void)testWritingStringToFile {
  NSString *uniqueString = [FIRCoreDiagnostics installString];
  XCTAssertNotNil(uniqueString);

  NSURL *filePathURL = [FIRCoreDiagnostics filePathURLWithName:kUniqueInstallFileName];
  XCTAssertTrue([filePathURL.path
      hasSuffix:@"Library/Application Support/Google/FIRApp/FIREBASE_UNIQUE_INSTALL"]);
  NSDictionary<NSString *, id> *values =
      [filePathURL resourceValuesForKeys:@[ NSURLIsExcludedFromBackupKey ] error:NULL];
  XCTAssertEqualObjects(values[NSURLIsExcludedFromBackupKey], @YES);

  NSString *content = [FIRCoreDiagnostics stringAtURL:filePathURL];
  XCTAssertTrue([uniqueString isEqualToString:content]);
  // Check whether the saved unique string follows the correct format.
  // A sample UUID: 5A870F63-078E-4D92-9145-EC2EF97E6681
  NSString *pattern = @"^[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}$";
  NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                         options:0
                                                                           error:nil];
  NSUInteger matchNumber = [regex numberOfMatchesInString:content
                                                  options:0
                                                    range:NSMakeRange(0, [content length])];
  XCTAssertTrue(matchNumber == 1);

  // Writing the same string to the same file again should still succeed.
  XCTAssertTrue([FIRCoreDiagnostics writeString:content toURL:filePathURL]);
}

// Populates the ICoreConfiguration proto.
- (void)populateProto:(logs_proto_mobilesdk_ios_ICoreConfiguration *)config {
  NSDictionary<NSString *, id> *info = [[NSBundle mainBundle] infoDictionary];
  NSString *xcodeVersion = info[@"DTXcodeBuild"];
  XCTAssertNotNil(xcodeVersion);
  NSString *sdkVersion = info[@"DTSDKBuild"];
  XCTAssertNotNil(sdkVersion);
  NSString *combinedVersions = [NSString stringWithFormat:@"%@-%@", xcodeVersion, sdkVersion];

  config->configuration_type = logs_proto_mobilesdk_ios_ICoreConfiguration_ConfigurationType_CORE;
  config->icore_version = FIREncodeString(kLibraryVersionID);
  config->pod_name = logs_proto_mobilesdk_ios_ICoreConfiguration_PodName_FIREBASE;
  config->has_pod_name = 1;
  config->app_id = FIREncodeString(kGoogleAppID);
  config->bundle_id = FIREncodeString(kBundleID);
  config->install = FIREncodeString([FIRCoreDiagnostics installString]);
  config->device_model = FIREncodeString([FIRCoreDiagnostics deviceModel]);
  config->os_version = FIREncodeString([[UIDevice currentDevice] systemVersion]);
  config->app_count = 1;
  config->has_app_count = 1;
  config->use_default_app = 1;
  config->has_use_default_app = 1;
  config->dynamic_framework_count = 3;
  config->has_dynamic_framework_count = 1;
  config->apple_framework_version = FIREncodeString(combinedVersions);
  config->min_supported_ios_version = FIREncodeString(@"8.0");
  config->using_zip_file = 0;
  config->has_using_zip_file = 1;
  config->deployment_type = logs_proto_mobilesdk_ios_ICoreConfiguration_DeploymentType_COCOAPODS;
  config->has_deployment_type = 1;
  config->deployed_in_app_store = 0;
  config->has_deployed_in_app_store = 1;
  config->swizzling_enabled = 1;
  config->has_swizzling_enabled = 1;
}

@end
