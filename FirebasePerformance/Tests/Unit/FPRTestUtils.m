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

#import "FirebasePerformance/Tests/Unit/FPRTestUtils.h"

#import "FirebasePerformance/Sources/FPRNanoPbUtils.h"
#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeData.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace+Private.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Private.h"

#import "FirebasePerformance/Sources/Protogen/nanopb/perf_metric.nanopb.h"

static NSInteger const kLogSource = 462;  // LogRequest_LogSource_Fireperf

@implementation FPRTestUtils

#pragma mark - Retrieve bundle

+ (NSBundle *)getBundle {
#if SWIFT_PACKAGE
  return SWIFTPM_MODULE_BUNDLE;
#else
  return [NSBundle bundleForClass:[FPRTestUtils class]];
#endif
}

#pragma mark - Create events and PerfMetrics
+ (FIRTrace *)createRandomTraceWithName:(NSString *)traceName {
  FIRTrace *trace = [[FIRTrace alloc] initWithName:traceName];
  [trace start];
  [trace stop];
  // Make sure there are no sessions.
  trace.activeSessions = [NSMutableArray array];

  return trace;
}

+ (FIRTrace *)addVerboseSessionToTrace:(FIRTrace *)trace {
  FPRSessionDetails *details =
      [[FPRSessionDetails alloc] initWithSessionId:@"random" options:FPRSessionOptionsGauges];
  trace.activeSessions = [[NSMutableArray alloc] initWithObjects:details, nil];

  return trace;
}

+ (firebase_perf_v1_PerfMetric)createRandomPerfMetric:(NSString *)traceName {
  firebase_perf_v1_PerfMetric perfMetric = FPRGetPerfMetricMessage(@"RandomAppID");
  FIRTrace *trace = [FPRTestUtils createRandomTraceWithName:traceName];
  // Make sure there are no sessions.
  trace.activeSessions = [NSMutableArray array];
  FPRSetTraceMetric(&perfMetric, FPRGetTraceMetric(trace));

  return perfMetric;
}

+ (firebase_perf_v1_PerfMetric)createVerboseRandomPerfMetric:(NSString *)traceName {
  firebase_perf_v1_PerfMetric perfMetric = FPRGetPerfMetricMessage(@"RandomAppID");
  FIRTrace *trace = [FPRTestUtils createRandomTraceWithName:traceName];
  trace = [FPRTestUtils addVerboseSessionToTrace:trace];
  FPRSetTraceMetric(&perfMetric, FPRGetTraceMetric(trace));

  return perfMetric;
}

+ (firebase_perf_v1_PerfMetric)createRandomInternalPerfMetric:(NSString *)traceName {
  firebase_perf_v1_PerfMetric perfMetric = FPRGetPerfMetricMessage(@"RandomAppID");

  FIRTrace *trace = [[FIRTrace alloc] initInternalTraceWithName:traceName];
  [trace start];
  [trace stop];
  // Make sure there are no sessions.
  trace.activeSessions = [NSMutableArray array];
  FPRSetTraceMetric(&perfMetric, FPRGetTraceMetric(trace));

  return perfMetric;
}

+ (firebase_perf_v1_PerfMetric)createRandomNetworkPerfMetric:(NSString *)url {
  firebase_perf_v1_PerfMetric perfMetric = FPRGetPerfMetricMessage(@"RandomAppID");

  NSURL *URL = [NSURL URLWithString:url];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *networkTrace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  [networkTrace start];
  [networkTrace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [networkTrace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];

  NSDictionary<NSString *, NSString *> *headerFields = @{@"Content-Type" : @"text/json"};
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URL
                                                            statusCode:200
                                                           HTTPVersion:@"HTTP/1.1"
                                                          headerFields:headerFields];
  [networkTrace didReceiveData:[NSData data]];
  [networkTrace didCompleteRequestWithResponse:response error:nil];
  networkTrace.activeSessions = [NSMutableArray array];
  FPRSetNetworkRequestMetric(&perfMetric, FPRGetNetworkRequestMetric(networkTrace));

  return perfMetric;
}

+ (firebase_perf_v1_PerfMetric)createRandomGaugePerfMetric {
  firebase_perf_v1_PerfMetric perfMetric = FPRGetPerfMetricMessage(@"RandomAppID");

  NSMutableArray<NSObject *> *gauges = [[NSMutableArray alloc] init];
  NSDate *date = [NSDate date];
  FPRMemoryGaugeData *memoryData = [[FPRMemoryGaugeData alloc] initWithCollectionTime:date
                                                                             heapUsed:5 * 1024
                                                                        heapAvailable:10 * 1024];
  [gauges addObject:memoryData];

  firebase_perf_v1_GaugeMetric gaugeMetric = FPRGetGaugeMetric(gauges, @"123");
  FPRSetGaugeMetric(&perfMetric, gaugeMetric);

  return perfMetric;
}

+ (GDTCOREvent *)createRandomTraceGDTEvent:(NSString *)traceName {
  firebase_perf_v1_PerfMetric perfMetric = [self createRandomPerfMetric:traceName];

  NSString *mappingID = [NSString stringWithFormat:@"%ld", (long)kLogSource];
  GDTCOREvent *gdtEvent = [[GDTCOREvent alloc] initWithMappingID:mappingID target:kGDTCORTargetFLL];
  gdtEvent.dataObject = [FPRGDTEvent gdtEventForPerfMetric:perfMetric];
  return gdtEvent;
}

+ (GDTCOREvent *)createRandomInternalTraceGDTEvent:(NSString *)traceName {
  firebase_perf_v1_PerfMetric perfMetric = [self createRandomInternalPerfMetric:traceName];

  NSString *mappingID = [NSString stringWithFormat:@"%ld", (long)kLogSource];
  GDTCOREvent *gdtEvent = [[GDTCOREvent alloc] initWithMappingID:mappingID target:kGDTCORTargetFLL];
  gdtEvent.dataObject = [FPRGDTEvent gdtEventForPerfMetric:perfMetric];
  return gdtEvent;
}

+ (GDTCOREvent *)createRandomNetworkGDTEvent:(NSString *)url {
  firebase_perf_v1_PerfMetric perfMetric = [self createRandomNetworkPerfMetric:url];

  NSString *mappingID = [NSString stringWithFormat:@"%ld", (long)kLogSource];
  GDTCOREvent *gdtEvent = [[GDTCOREvent alloc] initWithMappingID:mappingID target:kGDTCORTargetFLL];
  gdtEvent.dataObject = [FPRGDTEvent gdtEventForPerfMetric:perfMetric];
  return gdtEvent;
}

#pragma mark - Decode nanoPb pbData

NSData *FPRDecodeData(pb_bytes_array_t *pbData) {
  NSData *data = [NSData dataWithBytes:&(pbData->bytes) length:pbData->size];
  return data;
}

NSString *FPRDecodeString(pb_bytes_array_t *pbData) {
  NSData *data = FPRDecodeData(pbData);
  return [NSString stringWithCString:[data bytes] encoding:NSUTF8StringEncoding];
}

NSDictionary<NSString *, NSString *> *FPRDecodeStringToStringMap(StringToStringMap *map,
                                                                 NSInteger count) {
  NSMutableDictionary<NSString *, NSString *> *dict = [[NSMutableDictionary alloc] init];
  for (int i = 0; i < count; i++) {
    NSString *key = FPRDecodeString(map[i].key);
    NSString *value = FPRDecodeString(map[i].value);
    dict[key] = value;
  }
  return [dict copy];
}

NSDictionary<NSString *, NSNumber *> *_Nullable FPRDecodeStringToNumberMap(
    StringToNumberMap *_Nullable map, NSInteger count) {
  NSMutableDictionary<NSString *, NSNumber *> *dict = [[NSMutableDictionary alloc] init];
  for (int i = 0; i < count; i++) {
    if (map[i].has_value) {
      NSString *key = FPRDecodeString(map[i].key);
      NSNumber *value = [NSNumber numberWithLongLong:map[i].value];
      dict[key] = value;
    }
  }
  return [dict copy];
}

@end
