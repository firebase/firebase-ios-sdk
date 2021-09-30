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

#import "FirebasePerformance/Tests/Unit/Fakes/FPRFakeClient.h"

#import "FirebasePerformance/Sources/FPRClient+Private.h"

@implementation FPRFakeClient

- (instancetype)init {
  self = [super init];
  if (self = [super init]) {
    self.configured = YES;
  }
  return self;
}

- (void)logTrace:(FIRTrace *)trace {
  self.logTraceCalledTimes++;
}

- (void)logNetworkTrace:(FPRNetworkTrace *)trace {
  self.logNetworkTraceCalledTimes++;
}

- (void)logGaugeMetric:(NSArray *)gaugeData forSessionId:(NSString *)sessionId {
  self.logGaugeMetricCalledTimes++;
}

- (void)processAndLogEvent:(firebase_perf_v1_PerfMetric)event {
  self.processAndLogEventCalledTimes++;
}

@end
