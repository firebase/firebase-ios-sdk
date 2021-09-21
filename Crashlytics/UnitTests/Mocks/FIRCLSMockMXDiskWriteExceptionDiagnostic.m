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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXDiskWriteExceptionDiagnostic.h"

#if CLS_METRICKIT_SUPPORTED

@interface FIRCLSMockMXDiskWriteExceptionDiagnostic ()
@property(readwrite, strong, nonnull) FIRCLSMockMXCallStackTree *callStackTree;
@property(readwrite, strong, nonnull) NSMeasurement<NSUnitInformationStorage *> *totalWritesCaused;
@property(readwrite, strong, nonnull) FIRCLSMockMXMetadata *metaData;
@property(readwrite, strong, nonnull) NSString *applicationVersion;
@end

@implementation FIRCLSMockMXDiskWriteExceptionDiagnostic

@synthesize callStackTree = _callStackTree;
@synthesize totalWritesCaused = _totalWritesCaused;
@synthesize metaData = _metaData;
@synthesize applicationVersion = _applicationVersion;

- (instancetype)initWithCallStackTree:(FIRCLSMockMXCallStackTree *)callStackTree
                    totalWritesCaused:(NSMeasurement<NSUnitInformationStorage *> *)totalWritesCaused
                             metaData:(FIRCLSMockMXMetadata *)metaData
                   applicationVersion:(NSString *)applicationVersion {
  self = [super init];
  _callStackTree = callStackTree;
  _totalWritesCaused = totalWritesCaused;
  _applicationVersion = applicationVersion;
  _metaData = metaData;
  return self;
}

@end

#endif
