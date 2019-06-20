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
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif // TARGET_OS_IPHONE

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIROptionsInternal.h>
#import <FirebaseCoreDiagnosticsInterop/FIRCoreDiagnosticsData.h>
#import <FirebaseCoreDiagnosticsInterop/FIRCoreDiagnosticsInterop.h>
#import <GoogleDataTransport/GDTEventDataObject.h>
#import <GoogleDataTransport/GDTTransport.h>
#import <GoogleDataTransport/GDTEvent.h>
#import <GoogleDataTransportCCTSupport/GDTCCTPrioritizer.h>
#import <GoogleUtilities/GULUserDefaults.h>
#import <OCMock/OCMock.h>
#import <nanopb/pb_decode.h>
#import <nanopb/pb_encode.h>

#import "FIRCDLibrary/Protogen/nanopb/firebasecore.nanopb.h"

#import "FIRDiagnosticsDateFileStorage.h"

/** For testing use only. This symbol should be provided by */
Class FIRCoreDiagnosticsImplementation;

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
// Initialization.
+ (instancetype)sharedInstance;
- (instancetype)initWithTransport:(GDTTransport *)transport
             heartbeatDateStorage:(FIRDiagnosticsDateFileStorage *)heartbeatDateStorage;

// Properties.
@property(nonatomic, readonly) dispatch_queue_t diagnosticsQueue;
@property(nonatomic, readonly) GDTTransport *transport;
@property(nonatomic, readonly) FIRDiagnosticsDateFileStorage *heartbeatDateStorage;

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
- (void)sendDiagnosticsData:(nonnull id<FIRCoreDiagnosticsData>)diagnosticsData;

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
@property(nonatomic) FIRCoreDiagnostics *diagnostics;
@property(nonatomic) id mockDateStorage;
@property(nonatomic) id mockTransport;

@end

@implementation FIRCoreDiagnosticsTest

- (void)setUp {
  [super setUp];
  [FIROptions resetDefaultOptions];
  [FIRApp resetApps];

  self.mockTransport = OCMClassMock([GDTTransport class]);
  OCMStub([self.mockTransport eventForTransport])
  .andReturn([[GDTEvent alloc] initWithMappingID:@"111" target:2]);

  self.mockDateStorage = OCMClassMock([FIRDiagnosticsDateFileStorage class]);
  self.diagnostics = [[FIRCoreDiagnostics alloc] initWithTransport:self.mockTransport
                                              heartbeatDateStorage:self.mockDateStorage];
}

- (void)tearDown {
  self.diagnostics = nil;
  self.mockTransport = nil;
  self.mockDateStorage = nil;
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
  config->device_model = FIREncodeString([FIRCoreDiagnostics deviceModel]);
#if TARGET_OS_IPHONE
  config->os_version = FIREncodeString([[UIDevice currentDevice] systemVersion]);
#else
  config->os_version = FIREncodeString([[NSProcessInfo processInfo] operatingSystemVersionString]);
#endif // TARGET_OS_IPHONE
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

#pragma mark - Heartbeats

- (void)testHeartbeatNotSentTheSameDay {
  NSCalendar *calendar = [NSCalendar currentCalendar];

  NSCalendarUnit unitFlags = NSCalendarUnitDay | NSCalendarUnitYear | NSCalendarUnitMonth;
  NSDateComponents *dateComponents = [calendar components:unitFlags fromDate:[NSDate date]];

  // Verify start of the day
  NSDate *startOfTheDay = [calendar dateFromComponents:dateComponents];
  OCMExpect([self.mockDateStorage date]).andReturn(startOfTheDay);
  OCMReject([self.mockDateStorage setDate:[self OCMArgToCheckDateEqualTo:[OCMArg any]]
                                    error:[OCMArg anyObjectRef]]);

  [self assertEventSentWithHeartbeat:NO];

  // Verify middle of the day
  dateComponents.hour = 12;
  NSDate *middleOfTheDay = [calendar dateFromComponents:dateComponents];
  OCMExpect([self.mockDateStorage date]).andReturn(middleOfTheDay);
  OCMReject([self.mockDateStorage setDate:[self OCMArgToCheckDateEqualTo:[OCMArg any]]
                                    error:[OCMArg anyObjectRef]]);

  [self assertEventSentWithHeartbeat:NO];

  // Verify end of the day
  dateComponents.hour = 0;
  dateComponents.day += 1;
  NSDate *startOfNextDay = [calendar dateFromComponents:dateComponents];
  NSDate *endOfTheDay = [startOfNextDay dateByAddingTimeInterval:- 1];
  OCMExpect([self.mockDateStorage date]).andReturn(endOfTheDay);
  OCMReject([self.mockDateStorage setDate:[self OCMArgToCheckDateEqualTo:[OCMArg any]]
                                    error:[OCMArg anyObjectRef]]);

  [self assertEventSentWithHeartbeat:NO];
}

- (void)testHeartbeatSentNoPreviousCheckin {
  OCMExpect([self.mockDateStorage date]).andReturn(nil);
  OCMExpect([self.mockDateStorage setDate:[self OCMArgToCheckDateEqualTo:[NSDate date]]
                                    error:[OCMArg anyObjectRef]]);

  [self assertEventSentWithHeartbeat:YES];
}

- (void)testHeartbeatSentNextDayDefaultApp {
  NSDate *startOfToday = [[NSCalendar currentCalendar] startOfDayForDate:[NSDate date]];
  NSDate *endOfYesterday = [startOfToday dateByAddingTimeInterval:-1];

  OCMExpect([self.mockDateStorage date]).andReturn(endOfYesterday);
  OCMExpect([self.mockDateStorage setDate:[self OCMArgToCheckDateEqualTo:[NSDate date]]
                                    error:[OCMArg anyObjectRef]]);

  [self assertEventSentWithHeartbeat:YES];
}

#pragma mark - Singletone

- (void)testSharedInstanceDateStorageProperlyInitialized {
  FIRCoreDiagnostics *sharedInstance = [FIRCoreDiagnostics sharedInstance];
  XCTAssertNotNil(sharedInstance.heartbeatDateStorage);
  XCTAssert([sharedInstance.heartbeatDateStorage isKindOfClass:[FIRDiagnosticsDateFileStorage class]]);

  NSDate *date = [NSDate date];

  NSError *error;
  XCTAssertTrue([sharedInstance.heartbeatDateStorage setDate:date error:&error], @"Error %@", error);

  XCTAssertEqualObjects([sharedInstance.heartbeatDateStorage date], date);
}

#pragma mark - Helpers

- (void)assertEventSentWithHeartbeat:(BOOL)isHeartbeat {
  [self expectEventToBeSentToTransportWithHeartbeat:isHeartbeat];

  [self.diagnostics sendDiagnosticsData:[[FIRCoreDiagnosticsTestData alloc] init]];

  OCMVerifyAllWithDelay(self.mockTransport, 0.5);
  OCMVerifyAllWithDelay(self.mockDateStorage, 0.5);
}

- (void)expectEventToBeSentToTransportWithHeartbeat:(BOOL)isHeartbeat {
  id eventValidation = [OCMArg checkWithBlock:^BOOL(GDTEvent *obj) {
    XCTAssert([obj isKindOfClass:[GDTEvent class]]);
    FIRCoreDiagnosticsLog *dataObject = obj.dataObject;
    XCTAssert([dataObject isKindOfClass:[FIRCoreDiagnosticsLog class]]);

    BOOL isSentEventHeartbeat = dataObject.config.sdk_name == logs_proto_mobilesdk_ios_ICoreConfiguration_ServiceType_ICORE;
    XCTAssertEqual(isSentEventHeartbeat, isHeartbeat);

    return YES;
  }];
  OCMExpect([self.mockTransport sendTelemetryEvent:eventValidation]);
}

- (BOOL)isDate:(NSDate *)date1 approximatelyEqual:(NSDate *)date2 {
  NSTimeInterval precision = 10;
  NSTimeInterval diff = ABS([date1 timeIntervalSinceDate:date2]);
  return diff <= precision;
}

- (id)OCMArgToCheckDateEqualTo:(NSDate *)date {
  return [OCMArg checkWithBlock:^BOOL(id obj) {
    XCTAssert([obj isKindOfClass:[NSDate class]], "%@", self.name);
    return [self isDate:obj approximatelyEqual:date];
  }];
}

@end
