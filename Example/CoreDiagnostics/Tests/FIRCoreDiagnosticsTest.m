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
#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#endif  // TARGET_OS_IOS || TARGET_OS_TV

#import <GoogleUtilities/GULAppEnvironmentUtil.h>
#import <GoogleUtilities/GULHeartbeatDateStorage.h>
#import <GoogleUtilities/GULUserDefaults.h>
#import <OCMock/OCMock.h>
#import <nanopb/pb_decode.h>
#import <nanopb/pb_encode.h>
#import "GoogleDataTransport/GDTCORLibrary/Internal/GoogleDataTransportInternal.h"
#import "Interop/CoreDiagnostics/Public/FIRCoreDiagnosticsData.h"
#import "Interop/CoreDiagnostics/Public/FIRCoreDiagnosticsInterop.h"

#import "Firebase/CoreDiagnostics/FIRCDLibrary/Protogen/nanopb/firebasecore.nanopb.h"

extern NSString *const kFIRAppDiagnosticsNotification;
extern NSString *const kFIRLastCheckinDateKey;

static NSString *const kGoogleAppID = @"1:123:ios:123abc";
static NSString *const kBundleID = @"com.google.FirebaseSDKTests";
static NSString *const kLibraryVersionID = @"1.2.3";
static NSString *const kFIRCoreDiagnosticsHeartbeatTag = @"FIRCoreDiagnostics";

#pragma mark - Testing interfaces

@interface FIRCoreDiagnostics : NSObject
// Initialization.
+ (instancetype)sharedInstance;
- (instancetype)initWithTransport:(GDTCORTransport *)transport
             heartbeatDateStorage:(GULHeartbeatDateStorage *)heartbeatDateStorage;

// Properties.
@property(nonatomic, readonly) dispatch_queue_t diagnosticsQueue;
@property(nonatomic, readonly) GDTCORTransport *transport;
@property(nonatomic, readonly) GULHeartbeatDateStorage *heartbeatDateStorage;

// Install string helpers.
+ (NSString *)installString;
+ (BOOL)writeString:(NSString *)string toURL:(NSURL *)filePathURL;
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
    _diagnosticObjects =
        @{kFIRCDGoogleAppIDKey : kGoogleAppID, @"BUNDLE_ID" : kBundleID, kFIRCDllAppsCountKey : @1};
  }
  return self;
}

@end

@interface FIRCoreDiagnosticsLog : NSObject <GDTCOREventDataObject>

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

  self.mockTransport = OCMClassMock([GDTCORTransport class]);
  OCMStub([self.mockTransport eventForTransport])
      .andReturn([[GDTCOREvent alloc] initWithMappingID:@"111" target:2]);

  self.mockDateStorage = OCMClassMock([GULHeartbeatDateStorage class]);
  self.diagnostics = [[FIRCoreDiagnostics alloc] initWithTransport:self.mockTransport
                                              heartbeatDateStorage:self.mockDateStorage];
}

- (void)tearDown {
  self.diagnostics = nil;
  self.mockTransport = nil;
  self.mockDateStorage = nil;
  [super tearDown];
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
  icoreConfiguration.using_gdt = 1;
  icoreConfiguration.has_using_gdt = 1;
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
  NSString *xcodeVersion = info[@"DTXcodeBuild"] ?: @"";
  NSString *sdkVersion = info[@"DTSDKBuild"] ?: @"";
  NSString *combinedVersions = [NSString stringWithFormat:@"%@-%@", xcodeVersion, sdkVersion];

  config->using_gdt = 1;
  config->has_using_gdt = 1;
  config->configuration_type = logs_proto_mobilesdk_ios_ICoreConfiguration_ConfigurationType_CORE;
  config->icore_version = FIREncodeString(kLibraryVersionID);
  config->pod_name = logs_proto_mobilesdk_ios_ICoreConfiguration_PodName_FIREBASE;
  config->has_pod_name = 1;
  config->app_id = FIREncodeString(kGoogleAppID);
  config->bundle_id = FIREncodeString(kBundleID);
  config->device_model = FIREncodeString([GULAppEnvironmentUtil deviceModel]);
  config->os_version = FIREncodeString([GULAppEnvironmentUtil systemVersion]);
  config->app_count = 1;
  config->has_app_count = 1;
  config->use_default_app = 1;
  config->has_use_default_app = 1;

  int numFrameworks = -1;  // Subtract the app binary itself.
  unsigned int numImages;
  const char **imageNames = objc_copyImageNames(&numImages);
  for (unsigned int i = 0; i < numImages; i++) {
    NSString *imageName = [NSString stringWithUTF8String:imageNames[i]];
    if ([imageName rangeOfString:@"System/Library"].length != 0        // Apple .frameworks
        || [imageName rangeOfString:@"Developer/Library"].length != 0  // Xcode debug .frameworks
        || [imageName rangeOfString:@"usr/lib"].length != 0) {         // Public .dylibs
      continue;
    }
    numFrameworks++;
  }
  free(imageNames);
  config->dynamic_framework_count = numFrameworks;
  config->has_dynamic_framework_count = 1;
  config->apple_framework_version = FIREncodeString(combinedVersions);
  NSString *minVersion = [[NSBundle mainBundle] infoDictionary][@"MinimumOSVersion"];
  if (minVersion) {
    config->min_supported_ios_version = FIREncodeString(minVersion);
  }
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
  OCMExpect([self.mockDateStorage heartbeatDateForTag:kFIRCoreDiagnosticsHeartbeatTag])
      .andReturn(startOfTheDay);
  OCMReject([self.mockDateStorage setHearbeatDate:[self OCMArgToCheckDateEqualTo:[OCMArg any]]
                                           forTag:kFIRCoreDiagnosticsHeartbeatTag]);

  [self assertEventSentWithHeartbeat:NO];

  // Verify middle of the day
  dateComponents.hour = 12;
  NSDate *middleOfTheDay = [calendar dateFromComponents:dateComponents];
  OCMExpect([self.mockDateStorage heartbeatDateForTag:kFIRCoreDiagnosticsHeartbeatTag])
      .andReturn(middleOfTheDay);
  OCMReject([self.mockDateStorage setHearbeatDate:[self OCMArgToCheckDateEqualTo:[OCMArg any]]
                                           forTag:kFIRCoreDiagnosticsHeartbeatTag]);

  [self assertEventSentWithHeartbeat:NO];

  // Verify end of the day
  dateComponents.hour = 0;
  dateComponents.day += 1;
  NSDate *startOfNextDay = [calendar dateFromComponents:dateComponents];
  NSDate *endOfTheDay = [startOfNextDay dateByAddingTimeInterval:-1];
  OCMExpect([self.mockDateStorage heartbeatDateForTag:kFIRCoreDiagnosticsHeartbeatTag])
      .andReturn(endOfTheDay);
  OCMReject([self.mockDateStorage setHearbeatDate:[self OCMArgToCheckDateEqualTo:[OCMArg any]]
                                           forTag:kFIRCoreDiagnosticsHeartbeatTag]);
  [self assertEventSentWithHeartbeat:NO];
}

- (void)testHeartbeatSentNoPreviousCheckin {
  OCMExpect([self.mockDateStorage heartbeatDateForTag:kFIRCoreDiagnosticsHeartbeatTag])
      .andReturn(nil);
  OCMExpect([self.mockDateStorage setHearbeatDate:[self OCMArgToCheckDateEqualTo:[NSDate date]]
                                           forTag:kFIRCoreDiagnosticsHeartbeatTag]);

  [self assertEventSentWithHeartbeat:YES];
}

- (void)testHeartbeatSentNextDayDefaultApp {
  NSDate *startOfToday = [[NSCalendar currentCalendar] startOfDayForDate:[NSDate date]];
  NSDate *endOfYesterday = [startOfToday dateByAddingTimeInterval:-1];

  OCMExpect([self.mockDateStorage heartbeatDateForTag:kFIRCoreDiagnosticsHeartbeatTag])
      .andReturn(endOfYesterday);
  OCMExpect([self.mockDateStorage setHearbeatDate:[self OCMArgToCheckDateEqualTo:[NSDate date]]
                                           forTag:kFIRCoreDiagnosticsHeartbeatTag]);

  [self assertEventSentWithHeartbeat:YES];
}

#pragma mark - Singleton

- (void)testSharedInstanceDateStorageProperlyInitialized {
  FIRCoreDiagnostics *sharedInstance = [FIRCoreDiagnostics sharedInstance];
  XCTAssertNotNil(sharedInstance.heartbeatDateStorage);
  XCTAssert([sharedInstance.heartbeatDateStorage isKindOfClass:[GULHeartbeatDateStorage class]]);

  NSDate *date = [NSDate date];

  XCTAssertTrue([sharedInstance.heartbeatDateStorage
      setHearbeatDate:date
               forTag:kFIRCoreDiagnosticsHeartbeatTag]);
  XCTAssertEqualObjects(
      [sharedInstance.heartbeatDateStorage heartbeatDateForTag:kFIRCoreDiagnosticsHeartbeatTag],
      date);
}

#pragma mark - Helpers

- (void)assertEventSentWithHeartbeat:(BOOL)isHeartbeat {
  [self expectEventToBeSentToTransportWithHeartbeat:isHeartbeat];

  [self.diagnostics sendDiagnosticsData:[[FIRCoreDiagnosticsTestData alloc] init]];

  OCMVerifyAllWithDelay(self.mockTransport, 0.5);
  OCMVerifyAllWithDelay(self.mockDateStorage, 0.5);
}

- (void)expectEventToBeSentToTransportWithHeartbeat:(BOOL)isHeartbeat {
  id eventValidation = [OCMArg checkWithBlock:^BOOL(GDTCOREvent *obj) {
    XCTAssert([obj isKindOfClass:[GDTCOREvent class]]);
    FIRCoreDiagnosticsLog *dataObject = obj.dataObject;
    XCTAssert([dataObject isKindOfClass:[FIRCoreDiagnosticsLog class]]);

    BOOL isSentEventHeartbeat =
        dataObject.config.sdk_name == logs_proto_mobilesdk_ios_ICoreConfiguration_ServiceType_ICORE;
    isSentEventHeartbeat = isSentEventHeartbeat && dataObject.config.has_sdk_name;
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
