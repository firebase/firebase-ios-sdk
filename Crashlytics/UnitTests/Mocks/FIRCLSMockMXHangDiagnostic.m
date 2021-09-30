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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXHangDiagnostic.h"

#if CLS_METRICKIT_SUPPORTED

@interface FIRCLSMockMXHangDiagnostic ()
@property(readwrite, strong, nonnull) FIRCLSMockMXCallStackTree *callStackTree;
@property(readwrite, strong, nonnull) NSMeasurement<NSUnitDuration *> *hangDuration;
@property(readwrite, strong, nonnull) FIRCLSMockMXMetadata *metaData;
@property(readwrite, strong, nonnull) NSString *applicationVersion;
@end

@implementation FIRCLSMockMXHangDiagnostic

@synthesize callStackTree = _callStackTree;
@synthesize hangDuration = _hangDuration;
@synthesize applicationVersion = _applicationVersion;
@synthesize metaData = _metaData;

- (instancetype)initWithCallStackTree:(FIRCLSMockMXCallStackTree *)callStackTree
                         hangDuration:(NSMeasurement<NSUnitDuration *> *)hangDuration
                             metaData:(FIRCLSMockMXMetadata *)metaData
                   applicationVersion:(NSString *)applicationVersion API_AVAILABLE(ios(14)) {
  self = [super init];
  _callStackTree = callStackTree;
  _hangDuration = hangDuration;
  _applicationVersion = applicationVersion;
  _metaData = metaData;
  return self;
}

@end

#endif
