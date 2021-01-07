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

#import "FirebasePerformance/Sources/Loggers/FPRGDTEvent.h"

#import "FirebasePerformance/ProtoSupport/PerfMetric.pbobjc.h"

@interface FPRGDTEvent ()

/** Perf metric that is going to be converted. */
@property(nonatomic) FPRMSGPerfMetric *metric;

/**
 *  Creates an instance of FPRGDTEvent.
 *
 *  @param perfMetric Performance Event proto object that needs to be converted to FPRGDTEvent.
 *  @return Instance of FPRGDTEvent.
 */
- (instancetype)initForPerfMetric:(FPRMSGPerfMetric *)perfMetric;

@end

@implementation FPRGDTEvent

+ (instancetype)gdtEventForPerfMetric:(FPRMSGPerfMetric *)perfMetric {
  FPRGDTEvent *event = [[FPRGDTEvent alloc] initForPerfMetric:perfMetric];
  return event;
}

- (instancetype)initForPerfMetric:(FPRMSGPerfMetric *)perfMetric {
  if (self = [super init]) {
    _metric = perfMetric;
  }

  return self;
}

#pragma mark - GDTCOREventDataObject protocol methods

- (NSData *)transportBytes {
  return [self.metric data];
}

@end
