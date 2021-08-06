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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXDiagnosticPayload.h"

#if CLS_METRICKIT_SUPPORTED

@interface FIRCLSMockMXDiagnosticPayload ()
@property(readwrite, strong, nullable) NSArray<MXCPUExceptionDiagnostic *> *cpuExceptionDiagnostics;
@property(readwrite, strong, nullable)
    NSArray<MXDiskWriteExceptionDiagnostic *> *diskWriteExceptionDiagnostics;
@property(readwrite, strong, nullable) NSArray<MXHangDiagnostic *> *hangDiagnostics;
@property(readwrite, strong, nullable) NSArray<MXCrashDiagnostic *> *crashDiagnostics;
@property(readwrite, strong, nonnull) NSDate *timeStampBegin;
@property(readwrite, strong, nonnull) NSDate *timeStampEnd;
@end

@implementation FIRCLSMockMXDiagnosticPayload

@synthesize cpuExceptionDiagnostics = _cpuExceptionDiagnostics;
@synthesize diskWriteExceptionDiagnostics = _diskWriteExceptionDiagnostics;
@synthesize hangDiagnostics = _hangDiagnostics;
@synthesize crashDiagnostics = _crashDiagnostics;
@synthesize timeStampEnd = _timeStampEnd;
@synthesize timeStampBegin = _timeStampBegin;

- (instancetype)initWithDiagnostics:(NSDictionary *)diagnostics
                     timeStampBegin:(NSDate *)timeStampBegin
                       timeStampEnd:(NSDate *)timeStampEnd
                 applicationVersion:(NSString *)applicationVersion {
  self = [super init];
  _timeStampBegin = timeStampBegin;
  _timeStampEnd = timeStampEnd;
  _crashDiagnostics = [diagnostics objectForKey:@"crashes"];
  _hangDiagnostics = [diagnostics objectForKey:@"hangs"];
  _cpuExceptionDiagnostics = [diagnostics objectForKey:@"cpuExceptionDiagnostics"];
  _diskWriteExceptionDiagnostics = [diagnostics objectForKey:@"diskWriteExceptionDiagnostics"];
  return self;
}

@end

#endif
