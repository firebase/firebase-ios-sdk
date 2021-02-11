// Copyright 2020 Google LLC
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

#import <XCTest/XCTest.h>

#import "FirebasePerformance/Sources/FIRPerformance+Internal.h"
#import "FirebasePerformance/Sources/FPRDataUtils.h"
#import "FirebasePerformance/Sources/FPRProtoUtils.h"
#import "FirebasePerformance/Sources/Public/FIRPerformance.h"

#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace+Private.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Private.h"

#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeData.h"
#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeData.h"

#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"

#import <OCMock/OCMock.h>

@interface FPRProtoUtilsTest : FPRTestCase

@end

@implementation FPRProtoUtilsTest

- (void)setUp {
  [super setUp];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:YES];
}

- (void)tearDown {
  [super tearDown];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:NO];
}

/** Validates that a PerfMetricMessage creation is successful. */
- (void)testPerfMetricMessageCreation {
  NSString *appID = @"RandomAppID";
  FPRMSGPerfMetric *perfMetric = FPRGetPerfMetricMessage(appID);
  XCTAssertEqualObjects(perfMetric.applicationInfo.googleAppId, appID);
  XCTAssertNotNil(perfMetric.applicationInfo);
}

/** Tests if the application information is populated when creating a FPRMSGPerfMetric message. */
- (void)testApplicationInfoMessage {
  FPRMSGPerfMetric *event = FPRGetPerfMetricMessage(@"appid");
  FPRMSGApplicationInfo *appInfo = event.applicationInfo;
  XCTAssertEqual(appInfo.googleAppId, @"appid");
  XCTAssertNotNil(appInfo.iosAppInfo.sdkVersion);
  XCTAssertNotNil(appInfo.iosAppInfo.bundleShortVersion);
  XCTAssertTrue((appInfo.iosAppInfo.mccMnc.length == 0) || (appInfo.iosAppInfo.mccMnc.length == 6));
  XCTAssertTrue(appInfo.iosAppInfo.networkConnectionInfo.networkType !=
                FPRMSGNetworkConnectionInfo_NetworkType_None);
  if (appInfo.iosAppInfo.networkConnectionInfo.networkType ==
      FPRMSGNetworkConnectionInfo_NetworkType_Mobile) {
    XCTAssertTrue(appInfo.iosAppInfo.networkConnectionInfo.mobileSubtype !=
                  FPRMSGNetworkConnectionInfo_MobileSubtype_UnknownMobileSubtype);
  }
}

/** Validates that ApplicationInfoMessage carries global attributes. */
- (void)testApplicationInfoMessageWithAttributes {
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setValue:@"bar" forAttribute:@"foo"];
  FPRMSGPerfMetric *event = FPRGetPerfMetricMessage(@"appid");
  FPRMSGApplicationInfo *appInfo = event.applicationInfo;
  XCTAssertNotNil(appInfo.customAttributes);
  XCTAssertEqual(appInfo.customAttributes.allKeys.count, 1);
  NSDictionary *attributes = appInfo.customAttributes;
  XCTAssertEqual(attributes[@"foo"], @"bar");
  [performance removeAttribute:@"foo"];
}

/** Tests if mccMnc validation is catching non numerals. */
- (void)testMccMncOnlyHasNumbers {
  NSString *mccMnc = FPRValidatedMccMnc(@"123", @"MKV");
  XCTAssertNil(mccMnc);
  mccMnc = FPRValidatedMccMnc(@"ABC", @"123");
  XCTAssertNil(mccMnc);
}

/** Tests if mccMnc validation is working. */
- (void)testMccMnc {
  NSString *mccMnc = FPRValidatedMccMnc(@"123", @"22");
  XCTAssertNotNil(mccMnc);
  mccMnc = FPRValidatedMccMnc(@"123", @"223");
  XCTAssertNotNil(mccMnc);
}

/** Tests if mccMnc validation catches improper lengths. */
- (void)testMccMncLength {
  NSString *mccMnc = FPRValidatedMccMnc(@"12", @"22");
  XCTAssertNil(mccMnc);
  mccMnc = FPRValidatedMccMnc(@"123", @"2");
  XCTAssertNil(mccMnc);
}

/** Validates that a valid FIRTrace object to Proto conversion is successful. */
- (void)testTraceMetricMessageCreation {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace startStageNamed:@"1"];
  [trace startStageNamed:@"2"];
  [trace incrementMetric:@"c1" byInt:2];
  [trace setValue:@"bar" forAttribute:@"foo"];
  [trace stop];
  FPRMSGTraceMetric *traceMetric = FPRGetTraceMetric(trace);
  XCTAssertNotNil(traceMetric);
  XCTAssertEqualObjects(traceMetric.name, @"Random");
  XCTAssertEqual(traceMetric.subtracesArray.count, 2);
  XCTAssertEqual(traceMetric.counters.count, 1);
  XCTAssertEqualObjects(traceMetric.subtracesArray[0].name, @"1");
  XCTAssertEqualObjects(traceMetric.subtracesArray[1].name, @"2");
  XCTAssertNotNil(traceMetric.customAttributes);
  XCTAssertEqual(traceMetric.customAttributes.allKeys.count, 1);
  NSDictionary *attributes = traceMetric.customAttributes;
  XCTAssertEqual(attributes[@"foo"], @"bar");
}

/** Validates that a valid FIRTrace object to Proto conversion has required fields. */
- (void)testTraceMetricMessageCreationHasRequiredFields {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace incrementMetric:@"c1" byInt:2];
  [trace stop];
  FPRMSGTraceMetric *traceMetric = FPRGetTraceMetric(trace);
  XCTAssertNotNil(traceMetric);
  XCTAssertTrue(traceMetric.hasName);
  XCTAssertTrue(traceMetric.hasClientStartTimeUs);
  XCTAssertTrue(traceMetric.hasDurationUs);
  XCTAssertTrue(traceMetric.hasIsAuto);
}

/** Validates the session details inside trace metric. */
- (void)testTraceMetricMessageHasSessionDetails {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace incrementMetric:@"c1" byInt:2];

  FPRSessionDetails *session1 = [[FPRSessionDetails alloc] initWithSessionId:@"a"
                                                                     options:FPRSessionOptionsNone];
  FPRSessionDetails *session2 =
      [[FPRSessionDetails alloc] initWithSessionId:@"b" options:FPRSessionOptionsGauges];

  trace.activeSessions = [@[ session1, session2 ] mutableCopy];
  [trace stop];
  FPRMSGTraceMetric *traceMetric = FPRGetTraceMetric(trace);
  XCTAssertNotNil(traceMetric);
  XCTAssertNotNil(traceMetric.perfSessionsArray);
  XCTAssertTrue(traceMetric.perfSessionsArray.count >= 2);
}

/** Validates that an invalid FIRTrace object to Proto conversion is unsuccessful. */
- (void)testTraceMetricMessageCreationForInvalidTrace {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertNil(FPRGetTraceMetric(nil));
#pragma clang diagnostic pop
}

/** Validates that the FPRNetworkTrace object to Proto conversion is successful. */
- (void)testNetworkTraceMetricMessage {
  NSURL *URL = [NSURL URLWithString:@"https://abc.com"];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];

  NSDictionary<NSString *, NSString *> *headerFields = @{@"Content-Type" : @"text/json"};
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URLRequest.URL
                                                            statusCode:404
                                                           HTTPVersion:@"HTTP/1.1"
                                                          headerFields:headerFields];
  NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:-200 userInfo:nil];

  [trace didReceiveData:[NSData data]];
  [trace didCompleteRequestWithResponse:response error:error];
  FPRMSGNetworkRequestMetric *networkMetric = FPRGetNetworkRequestMetric(trace);
  XCTAssertEqualObjects(networkMetric.URL, URL.absoluteString);
  XCTAssertEqual(networkMetric.HTTPMethod, FPRMSGNetworkRequestMetric_HttpMethod_Get);
  XCTAssertEqual(networkMetric.networkClientErrorReason,
                 FPRMSGNetworkRequestMetric_NetworkClientErrorReason_GenericClientError);
  XCTAssertEqual(networkMetric.HTTPResponseCode, 404);
  XCTAssertEqualObjects(networkMetric.responseContentType, @"text/json");
}

/** Validates that the FPRNetworkTrace object to Proto conversion has required fields for a valid
 * response.
 */
- (void)testNetworkTraceMetricMessageHasAllRequiredFields {
  NSURL *URL = [NSURL URLWithString:@"https://abc.com"];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];

  NSDictionary<NSString *, NSString *> *headerFields = @{@"Content-Type" : @"text/json"};
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URLRequest.URL
                                                            statusCode:404
                                                           HTTPVersion:@"HTTP/1.1"
                                                          headerFields:headerFields];
  NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:-200 userInfo:nil];
  [trace didReceiveData:[NSData data]];
  [trace didCompleteRequestWithResponse:response error:error];
  FPRMSGNetworkRequestMetric *networkMetric = FPRGetNetworkRequestMetric(trace);
  XCTAssertTrue(networkMetric.hasURL);
  XCTAssertTrue(networkMetric.hasClientStartTimeUs);
  XCTAssertTrue(networkMetric.hasHTTPMethod);
  XCTAssertTrue(networkMetric.hasResponsePayloadBytes);
  XCTAssertTrue(networkMetric.hasNetworkClientErrorReason);
  XCTAssertTrue(networkMetric.hasHTTPResponseCode);
  XCTAssertTrue(networkMetric.hasResponseContentType);
  XCTAssertTrue(networkMetric.hasTimeToResponseCompletedUs);
}

/** Validates that an invalid FPRNetworkTrace object to Proto conversion is unsuccessful. */
- (void)testNetworkTraceMetricMessageCreationForInvalidTrace {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertNil(FPRGetNetworkRequestMetric(nil));
#pragma clang diagnostic pop
}

/** Validates that application process state conversion to proto enum type is successful. */
- (void)testApplicationProcessStateConversion {
  XCTAssertEqual(FPRMSGApplicationProcessState_Background,
                 FPRApplicationProcessState(FPRTraceStateBackgroundOnly));
  XCTAssertEqual(FPRMSGApplicationProcessState_Foreground,
                 FPRApplicationProcessState(FPRTraceStateForegroundOnly));
  XCTAssertEqual(FPRMSGApplicationProcessState_ForegroundBackground,
                 FPRApplicationProcessState(FPRTraceStateBackgroundAndForeground));
  XCTAssertEqual(FPRMSGApplicationProcessState_ApplicationProcessStateUnknown,
                 FPRApplicationProcessState(FPRTraceStateUnknown));

  // Try with some random value should say the application state is unknown.
  XCTAssertEqual(FPRMSGApplicationProcessState_ApplicationProcessStateUnknown,
                 FPRApplicationProcessState(100));
}

#if __has_include("CoreTelephony/CTTelephonyNetworkInfo.h")
/** Validates if network object creation works. */
- (void)testNetworkInfoObjectCreation {
  XCTAssertNotNil(FPRNetworkInfo());
}
#endif

/** Validates if network events are dropped when there is not valid response code. */
- (void)testDroppingNetworkEventsWithInvalidStatusCode {
  NSURL *URL = [NSURL URLWithString:@"https://abc.com"];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
  [trace didReceiveData:[NSData data]];
  [trace didCompleteRequestWithResponse:nil error:nil];
  XCTAssertNil(FPRGetNetworkRequestMetric(trace));
}

/** Validates the session details inside trace metric. */
- (void)testNetworkRequestMetricMessageHasSessionDetails {
  NSURL *URL = [NSURL URLWithString:@"https://abc.com"];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];

  NSDictionary<NSString *, NSString *> *headerFields = @{@"Content-Type" : @"text/json"};
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URLRequest.URL
                                                            statusCode:404
                                                           HTTPVersion:@"HTTP/1.1"
                                                          headerFields:headerFields];
  NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:-200 userInfo:nil];

  FPRSessionDetails *session1 = [[FPRSessionDetails alloc] initWithSessionId:@"a"
                                                                     options:FPRSessionOptionsNone];
  FPRSessionDetails *session2 =
      [[FPRSessionDetails alloc] initWithSessionId:@"b" options:FPRSessionOptionsGauges];
  trace.activeSessions = [@[ session1, session2 ] mutableCopy];

  [trace didReceiveData:[NSData data]];
  [trace didCompleteRequestWithResponse:response error:error];
  FPRMSGNetworkRequestMetric *networkMetric = FPRGetNetworkRequestMetric(trace);
  XCTAssertNotNil(networkMetric);
  XCTAssertNotNil(networkMetric.perfSessionsArray);
  XCTAssertTrue(networkMetric.perfSessionsArray.count >= 2);
}

/** Validates the gauge metric proto packaging works with proper conversions. */
- (void)testMemoryMetricProtoConversion {
  NSMutableArray *gauges = [[NSMutableArray alloc] init];
  NSDate *date = [NSDate date];
  FPRMemoryGaugeData *memoryData = [[FPRMemoryGaugeData alloc] initWithCollectionTime:date
                                                                             heapUsed:5 * 1024
                                                                        heapAvailable:10 * 1024];
  [gauges addObject:memoryData];

  FPRMSGGaugeMetric *gaugeMetric = FPRGetGaugeMetric(gauges, @"abc");
  XCTAssertNotNil(gaugeMetric);
  XCTAssertEqual(gaugeMetric.cpuMetricReadingsArray_Count, 0);
  XCTAssertEqual(gaugeMetric.iosMemoryReadingsArray_Count, 1);
  FPRMSGIosMemoryReading *memoryReading = [gaugeMetric.iosMemoryReadingsArray firstObject];
  XCTAssertEqual(memoryReading.usedAppHeapMemoryKb, 5);
  XCTAssertEqual(memoryReading.freeAppHeapMemoryKb, 10);
}

/** Validates the gauge metric proto packaging works. */
- (void)testGaugeMetricProtoPacking {
  NSMutableArray *gauges = [[NSMutableArray alloc] init];
  for (int i = 0; i < 5; i++) {
    NSDate *date = [NSDate date];
    FPRCPUGaugeData *cpuData = [[FPRCPUGaugeData alloc] initWithCollectionTime:date
                                                                    systemTime:100
                                                                      userTime:200];
    FPRMemoryGaugeData *memoryData = [[FPRMemoryGaugeData alloc] initWithCollectionTime:date
                                                                               heapUsed:100
                                                                          heapAvailable:200];
    [gauges addObject:cpuData];
    [gauges addObject:memoryData];
  }
  FPRMSGGaugeMetric *gaugeMetric = FPRGetGaugeMetric(gauges, @"abc");
  XCTAssertNotNil(gaugeMetric);
  XCTAssertEqual(gaugeMetric.cpuMetricReadingsArray_Count, 5);
  XCTAssertEqual(gaugeMetric.iosMemoryReadingsArray_Count, 5);
}

/** Validates the gauge metric proto packaging does not create an empty package. */
- (void)testGaugeMetricProtoPackingWithEmptyData {
  NSMutableArray *gauges = [[NSMutableArray alloc] init];
  FPRMSGGaugeMetric *gaugeMetric1 = FPRGetGaugeMetric(gauges, @"abc");
  XCTAssertNil(gaugeMetric1);

  FPRMSGGaugeMetric *gaugeMetric2 = FPRGetGaugeMetric(gauges, @"");
  XCTAssertNil(gaugeMetric2);
}

/** Validates if the first session is a verbose session for a trace. */
- (void)testOrderingOfSessionsForTrace {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  FPRSessionDetails *session1 = [[FPRSessionDetails alloc] initWithSessionId:@"a"
                                                                     options:FPRSessionOptionsNone];
  FPRSessionDetails *session2 =
      [[FPRSessionDetails alloc] initWithSessionId:@"b" options:FPRSessionOptionsGauges];

  trace.activeSessions = [@[ session1, session2 ] mutableCopy];
  [trace stop];

  FPRMSGTraceMetric *traceMetric = FPRGetTraceMetric(trace);
  XCTAssertNotNil(traceMetric);
  XCTAssertNotNil(traceMetric.perfSessionsArray);
  XCTAssertTrue(traceMetric.perfSessionsArray.count >= 2);

  FPRMSGPerfSession *perfSession = [traceMetric.perfSessionsArray firstObject];
  GPBEnumArray *firstSessionVerbosity = perfSession.sessionVerbosityArray;
  XCTAssertEqual([firstSessionVerbosity valueAtIndex:0],
                 FPRMSGSessionVerbosity_GaugesAndSystemEvents);
  XCTAssertEqualObjects(perfSession.sessionId, @"b");
}

/** Validates the verbosity ordering when no sessions are verbose. */
- (void)testOrderingOfNonVerboseSessionsForTrace {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  FPRSessionDetails *session1 = [[FPRSessionDetails alloc] initWithSessionId:@"a"
                                                                     options:FPRSessionOptionsNone];
  FPRSessionDetails *session2 = [[FPRSessionDetails alloc] initWithSessionId:@"b"
                                                                     options:FPRSessionOptionsNone];

  trace.activeSessions = [@[ session1, session2 ] mutableCopy];
  [trace stop];

  FPRMSGTraceMetric *traceMetric = FPRGetTraceMetric(trace);
  XCTAssertNotNil(traceMetric);
  XCTAssertNotNil(traceMetric.perfSessionsArray);
  XCTAssertTrue(traceMetric.perfSessionsArray.count >= 2);

  FPRMSGPerfSession *perfSession = [traceMetric.perfSessionsArray firstObject];
  XCTAssertEqualObjects(perfSession.sessionId, @"a");
  XCTAssertEqual(perfSession.sessionVerbosityArray_Count, 0);
}

/** Validates if a session is not verbose, do not populate the session verbosity array. */
- (void)testVerbosityArrayEmptyWhenTheSessionIsNotVerbose {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  FPRSessionDetails *session1 = [[FPRSessionDetails alloc] initWithSessionId:@"a"
                                                                     options:FPRSessionOptionsNone];

  trace.activeSessions = [@[ session1 ] mutableCopy];
  [trace stop];

  FPRMSGTraceMetric *traceMetric = FPRGetTraceMetric(trace);
  XCTAssertNotNil(traceMetric);
  XCTAssertNotNil(traceMetric.perfSessionsArray);
  XCTAssertTrue(traceMetric.perfSessionsArray.count >= 1);

  FPRMSGPerfSession *perfSession = [traceMetric.perfSessionsArray firstObject];
  XCTAssertEqualObjects(perfSession.sessionId, @"a");
  XCTAssertEqual(perfSession.sessionVerbosityArray_Count, 0);
}

/** Validates if the first session is a verbose session for a network trace. */
- (void)testOrderingOfSessionsForNetworkTrace {
  NSURL *URL = [NSURL URLWithString:@"https://abc.com"];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];

  NSDictionary<NSString *, NSString *> *headerFields = @{@"Content-Type" : @"text/json"};
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URLRequest.URL
                                                            statusCode:404
                                                           HTTPVersion:@"HTTP/1.1"
                                                          headerFields:headerFields];
  NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:-200 userInfo:nil];

  FPRSessionDetails *session1 = [[FPRSessionDetails alloc] initWithSessionId:@"a"
                                                                     options:FPRSessionOptionsNone];
  FPRSessionDetails *session2 =
      [[FPRSessionDetails alloc] initWithSessionId:@"b" options:FPRSessionOptionsGauges];

  trace.activeSessions = [@[ session1, session2 ] mutableCopy];

  [trace didReceiveData:[NSData data]];
  [trace didCompleteRequestWithResponse:response error:error];

  FPRMSGNetworkRequestMetric *networkMetric = FPRGetNetworkRequestMetric(trace);
  XCTAssertNotNil(networkMetric);
  XCTAssertNotNil(networkMetric.perfSessionsArray);
  XCTAssertTrue(networkMetric.perfSessionsArray.count >= 2);

  FPRMSGPerfSession *perfSession = [networkMetric.perfSessionsArray firstObject];
  GPBEnumArray *firstSessionVerbosity = perfSession.sessionVerbosityArray;
  XCTAssertEqual([firstSessionVerbosity valueAtIndex:0],
                 FPRMSGSessionVerbosity_GaugesAndSystemEvents);
  XCTAssertEqualObjects(perfSession.sessionId, @"b");
}

/** Validates the verbosity ordering when no sessions are verbose for a network trace. */
- (void)testOrderingOfNonVerboseSessionsForNetworkTrace {
  NSURL *URL = [NSURL URLWithString:@"https://abc.com"];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];

  NSDictionary<NSString *, NSString *> *headerFields = @{@"Content-Type" : @"text/json"};
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URLRequest.URL
                                                            statusCode:404
                                                           HTTPVersion:@"HTTP/1.1"
                                                          headerFields:headerFields];
  NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:-200 userInfo:nil];

  FPRSessionDetails *session1 = [[FPRSessionDetails alloc] initWithSessionId:@"a"
                                                                     options:FPRSessionOptionsNone];
  FPRSessionDetails *session2 = [[FPRSessionDetails alloc] initWithSessionId:@"b"
                                                                     options:FPRSessionOptionsNone];

  trace.activeSessions = [@[ session1, session2 ] mutableCopy];

  [trace didReceiveData:[NSData data]];
  [trace didCompleteRequestWithResponse:response error:error];

  FPRMSGNetworkRequestMetric *networkMetric = FPRGetNetworkRequestMetric(trace);
  XCTAssertNotNil(networkMetric);
  XCTAssertNotNil(networkMetric.perfSessionsArray);
  XCTAssertTrue(networkMetric.perfSessionsArray.count >= 2);

  FPRMSGPerfSession *perfSession = [networkMetric.perfSessionsArray firstObject];
  XCTAssertEqualObjects(perfSession.sessionId, @"a");
  XCTAssertEqual(perfSession.sessionVerbosityArray_Count, 0);
}

/** Validates if a session is not verbose, do not populate the session verbosity array for network
 *  trace.
 */
- (void)testVerbosityArrayEmptyWhenTheSessionIsNotVerboseForNetworkTrace {
  NSURL *URL = [NSURL URLWithString:@"https://abc.com"];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];

  NSDictionary<NSString *, NSString *> *headerFields = @{@"Content-Type" : @"text/json"};
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URLRequest.URL
                                                            statusCode:404
                                                           HTTPVersion:@"HTTP/1.1"
                                                          headerFields:headerFields];
  NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:-200 userInfo:nil];

  FPRSessionDetails *session1 = [[FPRSessionDetails alloc] initWithSessionId:@"a"
                                                                     options:FPRSessionOptionsNone];

  trace.activeSessions = [@[ session1 ] mutableCopy];

  [trace didReceiveData:[NSData data]];
  [trace didCompleteRequestWithResponse:response error:error];

  FPRMSGNetworkRequestMetric *networkMetric = FPRGetNetworkRequestMetric(trace);
  XCTAssertNotNil(networkMetric);
  XCTAssertNotNil(networkMetric.perfSessionsArray);
  XCTAssertTrue(networkMetric.perfSessionsArray.count >= 1);

  FPRMSGPerfSession *perfSession = [networkMetric.perfSessionsArray firstObject];
  XCTAssertEqualObjects(perfSession.sessionId, @"a");
  XCTAssertEqual(perfSession.sessionVerbosityArray_Count, 0);
}

@end
