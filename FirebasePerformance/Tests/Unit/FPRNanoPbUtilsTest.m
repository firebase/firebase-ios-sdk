// Copyright 2021 Google LLC
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
#import "FirebasePerformance/Sources/FPRNanoPbUtils.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"

#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace+Private.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Private.h"

#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeData.h"
#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeData.h"

#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"
#import "FirebasePerformance/Tests/Unit/FPRTestUtils.h"

#import <OCMock/OCMock.h>

@interface FPRNanoPbUtilsTest : FPRTestCase

@end

@implementation FPRNanoPbUtilsTest

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

/** Validates that a firebase_perf_v1_PerfMetric creation is successful. */
- (void)testPerfMetricMessageCreation {
  NSString *appID = @"RandomAppID";
  firebase_perf_v1_PerfMetric perfMetric = FPRGetPerfMetricMessage(appID);
  XCTAssertEqualObjects(FPRDecodeString(perfMetric.application_info.google_app_id), appID);
}

/** Tests if the application information is populated when creating a firebase_perf_v1_PerfMetric.
 */
- (void)testApplicationInfoMessage {
  firebase_perf_v1_PerfMetric event = FPRGetPerfMetricMessage(@"appid");
  firebase_perf_v1_ApplicationInfo appInfo = event.application_info;
  XCTAssertEqualObjects(FPRDecodeString(appInfo.google_app_id), @"appid");
  XCTAssertTrue(appInfo.ios_app_info.sdk_version != NULL);
  XCTAssertTrue(appInfo.has_ios_app_info);
  XCTAssertTrue(appInfo.ios_app_info.bundle_short_version != NULL);
  XCTAssertTrue(appInfo.ios_app_info.mcc_mnc == NULL || appInfo.ios_app_info.mcc_mnc->size == 6);
  XCTAssertTrue(appInfo.ios_app_info.has_network_connection_info);
  XCTAssertTrue(appInfo.ios_app_info.network_connection_info.has_network_type);
  XCTAssertTrue(appInfo.ios_app_info.network_connection_info.network_type !=
                firebase_perf_v1_NetworkConnectionInfo_NetworkType_NONE);
  if (appInfo.ios_app_info.network_connection_info.network_type ==
      firebase_perf_v1_NetworkConnectionInfo_NetworkType_MOBILE) {
    XCTAssertTrue(appInfo.ios_app_info.network_connection_info.mobile_subtype !=
                  firebase_perf_v1_NetworkConnectionInfo_MobileSubtype_UNKNOWN_MOBILE_SUBTYPE);
  }
}

/** Validates that ApplicationInfoMessage carries global attributes. */
- (void)testApplicationInfoMessageWithAttributes {
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setValue:@"bar1" forAttribute:@"foo1"];
  [performance setValue:@"bar2" forAttribute:@"foo2"];
  firebase_perf_v1_PerfMetric event = FPRGetPerfMetricMessage(@"appid");
  firebase_perf_v1_ApplicationInfo appInfo = event.application_info;
  XCTAssertEqual(appInfo.custom_attributes_count, 2);
  NSDictionary *attributes = FPRDecodeStringToStringMap(
      (StringToStringMap *)appInfo.custom_attributes, appInfo.custom_attributes_count);
  XCTAssertEqualObjects(attributes[@"foo1"], @"bar1");
  XCTAssertEqualObjects(attributes[@"foo2"], @"bar2");
  [performance removeAttribute:@"foo1"];
  [performance removeAttribute:@"foo2"];
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

/** Validates that a valid FIRTrace object to firebase_perf_v1_TraceMetric conversion is successful.
 */
- (void)testTraceMetricMessageCreation {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace startStageNamed:@"1"];
  [trace startStageNamed:@"2"];
  [trace incrementMetric:@"c1" byInt:2];
  [trace setValue:@"bar" forAttribute:@"foo"];
  [trace stop];
  firebase_perf_v1_TraceMetric traceMetric = FPRGetTraceMetric(trace);
  XCTAssertEqualObjects(FPRDecodeString(traceMetric.name), @"Random");
  XCTAssertEqual(traceMetric.subtraces_count, 2);
  XCTAssertEqual(traceMetric.counters_count, 1);
  NSDictionary *counters = FPRDecodeStringToNumberMap((StringToNumberMap *)traceMetric.counters,
                                                      traceMetric.counters_count);
  XCTAssertEqual([counters[@"c1"] intValue], 2);
  XCTAssertEqualObjects(FPRDecodeString(traceMetric.subtraces[0].name), @"1");
  XCTAssertEqualObjects(FPRDecodeString(traceMetric.subtraces[1].name), @"2");
  XCTAssertTrue(traceMetric.custom_attributes != NULL);
  XCTAssertEqual(traceMetric.custom_attributes_count, 1);
  NSDictionary *attributes = FPRDecodeStringToStringMap(
      (StringToStringMap *)traceMetric.custom_attributes, traceMetric.custom_attributes_count);
  XCTAssertEqualObjects(attributes[@"foo"], @"bar");
}

/** Validates that a valid FIRTrace object to firebase_perf_v1_TraceMetric conversion has required
 * fields. */
- (void)testTraceMetricMessageCreationHasRequiredFields {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  [trace incrementMetric:@"c1" byInt:2];
  [trace stop];
  firebase_perf_v1_TraceMetric traceMetric = FPRGetTraceMetric(trace);
  XCTAssertTrue(traceMetric.name != NULL);
  XCTAssertTrue(traceMetric.has_client_start_time_us);
  XCTAssertTrue(traceMetric.has_duration_us);
  XCTAssertTrue(traceMetric.has_is_auto);
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
  firebase_perf_v1_TraceMetric traceMetric = FPRGetTraceMetric(trace);
  XCTAssertTrue(traceMetric.perf_sessions != NULL);
  XCTAssertTrue(traceMetric.perf_sessions_count >= 2);
}

/** Validates that the FPRNetworkTrace object to firebase_perf_v1_NetworkRequestMetric conversion is
 * successful. */
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
  firebase_perf_v1_NetworkRequestMetric networkMetric = FPRGetNetworkRequestMetric(trace);
  XCTAssertEqualObjects(FPRDecodeString(networkMetric.url), URL.absoluteString);
  XCTAssertEqual(networkMetric.http_method, firebase_perf_v1_NetworkRequestMetric_HttpMethod_GET);
  XCTAssertEqual(
      networkMetric.network_client_error_reason,
      firebase_perf_v1_NetworkRequestMetric_NetworkClientErrorReason_GENERIC_CLIENT_ERROR);
  XCTAssertEqual(networkMetric.http_response_code, 404);
  XCTAssertEqualObjects(FPRDecodeString(networkMetric.response_content_type), @"text/json");
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
  firebase_perf_v1_NetworkRequestMetric networkMetric = FPRGetNetworkRequestMetric(trace);
  XCTAssertTrue(networkMetric.url != NULL);
  XCTAssertTrue(networkMetric.has_client_start_time_us);
  XCTAssertTrue(networkMetric.has_http_method);
  XCTAssertTrue(networkMetric.has_response_payload_bytes);
  XCTAssertTrue(networkMetric.has_network_client_error_reason);
  XCTAssertTrue(networkMetric.has_http_response_code);
  XCTAssertTrue(networkMetric.response_content_type != NULL);
  XCTAssertTrue(networkMetric.has_time_to_response_completed_us);
}

/** Validates that application process state conversion to firebase_perf_v1_ApplicationProcessState
 * enum type is successful. */
- (void)testApplicationProcessStateConversion {
  XCTAssertEqual(firebase_perf_v1_ApplicationProcessState_BACKGROUND,
                 FPRApplicationProcessState(FPRTraceStateBackgroundOnly));
  XCTAssertEqual(firebase_perf_v1_ApplicationProcessState_FOREGROUND,
                 FPRApplicationProcessState(FPRTraceStateForegroundOnly));
  XCTAssertEqual(firebase_perf_v1_ApplicationProcessState_FOREGROUND_BACKGROUND,
                 FPRApplicationProcessState(FPRTraceStateBackgroundAndForeground));
  XCTAssertEqual(firebase_perf_v1_ApplicationProcessState_APPLICATION_PROCESS_STATE_UNKNOWN,
                 FPRApplicationProcessState(FPRTraceStateUnknown));

  // Try with some random value should say the application state is unknown.
  XCTAssertEqual(firebase_perf_v1_ApplicationProcessState_APPLICATION_PROCESS_STATE_UNKNOWN,
                 FPRApplicationProcessState(100));
}

#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
/** Validates if network object creation works. */
- (void)testNetworkInfoObjectCreation {
  XCTAssertNotNil(FPRNetworkInfo());
}
#endif

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
  firebase_perf_v1_NetworkRequestMetric networkMetric = FPRGetNetworkRequestMetric(trace);
  XCTAssertTrue(networkMetric.perf_sessions != NULL);
  XCTAssertTrue(networkMetric.perf_sessions_count >= 2);
}

/** Validates the gauge metric proto packaging works with proper conversions. */
- (void)testMemoryMetricProtoConversion {
  NSMutableArray *gauges = [[NSMutableArray alloc] init];
  NSDate *date = [NSDate date];
  FPRMemoryGaugeData *memoryData = [[FPRMemoryGaugeData alloc] initWithCollectionTime:date
                                                                             heapUsed:5 * 1024
                                                                        heapAvailable:10 * 1024];
  [gauges addObject:memoryData];

  firebase_perf_v1_GaugeMetric gaugeMetric = FPRGetGaugeMetric(gauges, @"abc");
  XCTAssertEqual(gaugeMetric.cpu_metric_readings_count, 0);
  XCTAssertEqual(gaugeMetric.ios_memory_readings_count, 1);
  XCTAssertEqual(gaugeMetric.ios_memory_readings[0].used_app_heap_memory_kb, 5);
  XCTAssertEqual(gaugeMetric.ios_memory_readings[0].free_app_heap_memory_kb, 10);
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
  firebase_perf_v1_GaugeMetric gaugeMetric = FPRGetGaugeMetric(gauges, @"abc");
  XCTAssertEqual(gaugeMetric.cpu_metric_readings_count, 5);
  XCTAssertEqual(gaugeMetric.ios_memory_readings_count, 5);
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

  firebase_perf_v1_TraceMetric traceMetric = FPRGetTraceMetric(trace);
  XCTAssertTrue(traceMetric.perf_sessions != NULL);
  XCTAssertTrue(traceMetric.perf_sessions_count >= 2);

  firebase_perf_v1_PerfSession perfSession = traceMetric.perf_sessions[0];
  XCTAssertEqual(perfSession.session_verbosity[0],
                 firebase_perf_v1_SessionVerbosity_GAUGES_AND_SYSTEM_EVENTS);
  XCTAssertEqualObjects(FPRDecodeString(perfSession.session_id), @"b");
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

  firebase_perf_v1_TraceMetric traceMetric = FPRGetTraceMetric(trace);
  XCTAssertTrue(traceMetric.perf_sessions != NULL);
  XCTAssertTrue(traceMetric.perf_sessions_count >= 2);

  firebase_perf_v1_PerfSession perfSession = traceMetric.perf_sessions[0];
  XCTAssertEqualObjects(FPRDecodeString(perfSession.session_id), @"a");
  XCTAssertEqual(perfSession.session_verbosity_count, 0);
}

/** Validates if a session is not verbose, do not populate the session verbosity array. */
- (void)testVerbosityArrayEmptyWhenTheSessionIsNotVerbose {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:@"Random"];
  [trace start];
  FPRSessionDetails *session1 = [[FPRSessionDetails alloc] initWithSessionId:@"a"
                                                                     options:FPRSessionOptionsNone];

  trace.activeSessions = [@[ session1 ] mutableCopy];
  [trace stop];

  firebase_perf_v1_TraceMetric traceMetric = FPRGetTraceMetric(trace);
  XCTAssertTrue(traceMetric.perf_sessions != NULL);
  XCTAssertTrue(traceMetric.perf_sessions_count >= 1);

  firebase_perf_v1_PerfSession perfSession = traceMetric.perf_sessions[0];
  XCTAssertEqualObjects(FPRDecodeString(perfSession.session_id), @"a");
  XCTAssertEqual(perfSession.session_verbosity_count, 0);
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

  firebase_perf_v1_NetworkRequestMetric networkMetric = FPRGetNetworkRequestMetric(trace);
  XCTAssertTrue(networkMetric.perf_sessions != NULL);
  XCTAssertTrue(networkMetric.perf_sessions_count >= 2);

  firebase_perf_v1_PerfSession perfSession = networkMetric.perf_sessions[0];
  XCTAssertEqual(perfSession.session_verbosity[0],
                 firebase_perf_v1_SessionVerbosity_GAUGES_AND_SYSTEM_EVENTS);
  XCTAssertEqualObjects(FPRDecodeString(perfSession.session_id), @"b");
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

  firebase_perf_v1_NetworkRequestMetric networkMetric = FPRGetNetworkRequestMetric(trace);
  XCTAssertTrue(networkMetric.perf_sessions != NULL);
  XCTAssertTrue(networkMetric.perf_sessions_count >= 2);

  firebase_perf_v1_PerfSession perfSession = networkMetric.perf_sessions[0];
  XCTAssertEqualObjects(FPRDecodeString(perfSession.session_id), @"a");
  XCTAssertEqual(perfSession.session_verbosity_count, 0);
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

  firebase_perf_v1_NetworkRequestMetric networkMetric = FPRGetNetworkRequestMetric(trace);
  XCTAssertTrue(networkMetric.perf_sessions != NULL);
  XCTAssertTrue(networkMetric.perf_sessions_count >= 1);

  firebase_perf_v1_PerfSession perfSession = networkMetric.perf_sessions[0];
  XCTAssertEqualObjects(FPRDecodeString(perfSession.session_id), @"a");
  XCTAssertEqual(perfSession.session_verbosity_count, 0);
}

@end
