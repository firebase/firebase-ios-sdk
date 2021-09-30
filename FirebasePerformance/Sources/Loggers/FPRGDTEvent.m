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

#import <nanopb/pb.h>
#import <nanopb/pb_decode.h>
#import <nanopb/pb_encode.h>

#import "FirebasePerformance/Sources/FPRConsoleLogger.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTEvent.h"

#import "FirebasePerformance/Sources/Protogen/nanopb/perf_metric.nanopb.h"

@interface FPRGDTEvent ()

/** Perf metric that is going to be converted. */
@property(nonatomic) firebase_perf_v1_PerfMetric metric;

/**
 *  Creates an instance of FPRGDTEvent.
 *
 *  @param perfMetric Performance Event proto object that needs to be converted to FPRGDTEvent.
 *  @return Instance of FPRGDTEvent.
 */
- (instancetype)initForPerfMetric:(firebase_perf_v1_PerfMetric)perfMetric;

@end

@implementation FPRGDTEvent

+ (instancetype)gdtEventForPerfMetric:(firebase_perf_v1_PerfMetric)perfMetric {
  FPRGDTEvent *event = [[FPRGDTEvent alloc] initForPerfMetric:perfMetric];
  return event;
}

- (instancetype)initForPerfMetric:(firebase_perf_v1_PerfMetric)perfMetric {
  if (self = [super init]) {
    _metric = perfMetric;
  }

  return self;
}

#pragma mark - GDTCOREventDataObject protocol methods

- (NSData *)transportBytes {
  pb_ostream_t sizestream = PB_OSTREAM_SIZING;

  // Encode 1 time to determine the size.
  if (!pb_encode(&sizestream, firebase_perf_v1_PerfMetric_fields, &_metric)) {
    FPRLogError(kFPRTransportBytesError, @"Error in nanopb encoding for size: %s",
                PB_GET_ERROR(&sizestream));
  }

  // Encode a 2nd time to actually get the bytes from it.
  size_t bufferSize = sizestream.bytes_written;
  CFMutableDataRef dataRef = CFDataCreateMutable(CFAllocatorGetDefault(), bufferSize);
  CFDataSetLength(dataRef, bufferSize);
  pb_ostream_t ostream = pb_ostream_from_buffer((void *)CFDataGetBytePtr(dataRef), bufferSize);
  if (!pb_encode(&ostream, firebase_perf_v1_PerfMetric_fields, &_metric)) {
    FPRLogError(kFPRTransportBytesError, @"Error in nanopb encoding for bytes: %s",
                PB_GET_ERROR(&ostream));
  }
  CFDataSetLength(dataRef, ostream.bytes_written);

  return CFBridgingRelease(dataRef);
}

- (void)dealloc {
  pb_release(firebase_perf_v1_PerfMetric_fields, &_metric);
}

@end
