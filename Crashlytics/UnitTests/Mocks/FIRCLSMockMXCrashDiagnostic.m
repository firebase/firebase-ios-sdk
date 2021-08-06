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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXCrashDiagnostic.h"

#if CLS_METRICKIT_SUPPORTED

@interface FIRCLSMockMXCrashDiagnostic ()
@property(readwrite, strong, nonnull) FIRCLSMockMXCallStackTree *callStackTree;
@property(readwrite, strong, nonnull) NSString *terminationReason;
@property(readwrite, strong, nonnull) NSString *virtualMemoryRegionInfo;
@property(readwrite, strong, nonnull) NSNumber *exceptionType;
@property(readwrite, strong, nonnull) NSNumber *exceptionCode;
@property(readwrite, strong, nonnull) NSNumber *signal;
@property(readwrite, strong, nonnull) FIRCLSMockMXMetadata *metaData;
@property(readwrite, strong, nonnull) NSString *applicationVersion;
@end

@implementation FIRCLSMockMXCrashDiagnostic

@synthesize callStackTree = _callStackTree;
@synthesize terminationReason = _terminationReason;
@synthesize virtualMemoryRegionInfo = _virtualMemoryRegionInfo;
@synthesize exceptionType = _exceptionType;
@synthesize exceptionCode = _exceptionCode;
@synthesize signal = _signal;
@synthesize metaData = _metaData;
@synthesize applicationVersion = _applicationVersion;

- (instancetype)initWithCallStackTree:(FIRCLSMockMXCallStackTree *)callStackTree
                    terminationReason:(NSString *)terminationReason
              virtualMemoryRegionInfo:(NSString *)virtualMemoryRegionInfo
                        exceptionType:(NSNumber *)exceptionType
                        exceptionCode:(NSNumber *)exceptionCode
                               signal:(NSNumber *)signal
                             metaData:(FIRCLSMockMXMetadata *)metaData
                   applicationVersion:(NSString *)applicationVersion {
  self = [super init];
  _callStackTree = callStackTree;
  _terminationReason = terminationReason;
  _virtualMemoryRegionInfo = virtualMemoryRegionInfo;
  _exceptionCode = exceptionCode;
  _exceptionType = exceptionType;
  _signal = signal;
  _applicationVersion = applicationVersion;
  _metaData = metaData;
  return self;
}

@end

#endif
