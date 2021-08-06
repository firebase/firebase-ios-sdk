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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXCPUExceptionDiagnostic.h"

#if CLS_METRICKIT_SUPPORTED

@interface FIRCLSMockMXCPUExceptionDiagnostic ()
@property(readwrite, strong, nonnull) FIRCLSMockMXCallStackTree *callStackTree;
@property(readwrite, strong, nonnull) NSMeasurement<NSUnitDuration *> *totalCPUTime;
@property(readwrite, strong, nonnull) NSMeasurement<NSUnitDuration *> *totalSampledTime;
@property(readwrite, strong, nonnull) FIRCLSMockMXMetadata *metaData;
@property(readwrite, strong, nonnull) NSString *applicationVersion;
@end

@implementation FIRCLSMockMXCPUExceptionDiagnostic

@synthesize callStackTree = _callStackTree;
@synthesize totalCPUTime = _totalCPUTime;
@synthesize totalSampledTime = _totalSampledTime;
@synthesize metaData = _metaData;
@synthesize applicationVersion = _applicationVersion;

- (instancetype)initWithCallStackTree:(FIRCLSMockMXCallStackTree *)callStackTree
                         totalCPUTime:(NSMeasurement<NSUnitDuration *> *)totalCPUTime
                     totalSampledTime:(NSMeasurement<NSUnitDuration *> *)totalSampledTime
                             metaData:(FIRCLSMockMXMetadata *)metaData
                   applicationVersion:(NSString *)applicationVersion {
  self = [super init];
  _totalSampledTime = totalSampledTime;
  _totalCPUTime = totalCPUTime;
  _callStackTree = callStackTree;
  _applicationVersion = applicationVersion;
  _metaData = metaData;
  return self;
}

@end

#endif
