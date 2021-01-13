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

#import "PerfTraceMaker.h"

#import "FirebasePerformance/FIRPerformance.h"
#import "PerfE2EUtils.h"

static const NSInteger kTraceMaxCounters = 32;

@implementation PerfTraceMaker

+ (FIRTrace *)createTraceWithName:(NSString *)name
                         duration:(NSTimeInterval)duration
                         delegate:(id<PerfTraceDelegate>)delegate {
  FIRTrace *trace = [FIRPerformance startTraceWithName:name];
  [delegate traceStarted];

  NSDate *startTime = [NSDate date];
  NSInteger traceCount = [[name substringFromIndex:1] integerValue];

  // Increment metric.
  for (int i = 0; i < kTraceMaxCounters; i++) {
    NSString *counterName = [NSString stringWithFormat:@"%@c%02d", trace.name, i];
    NSInteger counterMeanValue = traceCount + i + 5;
    NSInteger counterValue = (int)randomGaussianValueWithMeanAndDeviation(counterMeanValue, 1);
    [trace incrementMetric:counterName byInt:counterValue];
  }

  // Set custom attributes.
  for (int i = 0; i < 5; i++) {
    NSString *attributeName = [NSString stringWithFormat:@"d%d", i];
    NSString *attributeValue = [NSString stringWithFormat:@"t%ld_d%d", traceCount, i];
    [trace setValue:attributeValue forAttribute:attributeName];
  }

  NSTimeInterval processingDuration = ABS([startTime timeIntervalSinceNow]);

  // Wait for the duration specified.
  [NSThread sleepForTimeInterval:(duration - processingDuration)];

  [trace stop];
  [delegate traceCompleted];
  return trace;
}

@end
