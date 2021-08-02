// Copyright 2021 Google
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

@implementation FIRCLSMockMXCrashDiagnostic

- (instancetype)initWithCallStackTree:(FIRCLSMockMXCallStackTree *)callStackTree
                    terminationReason:(NSString *)terminationReason
              virtualMemoryRegionInfo:(NSString *)virtualMemoryRegionInfo
                        exceptionType:(NSNumber *)exceptionType
                        exceptionCode:(NSNumber *)exceptionCode
                               signal:(NSNumber *)signal
                             metadata:(FIRCLSMockMXMetadata *)metadata
                   applicationVersion:(NSString *)applicationVersion {
  self.callStackTree = callStackTree;
  self.terminationReason = terminationReason;
  self.virtualMemoryRegionInfo = virtualMemoryRegionInfo;
  self.exceptionCode = exceptionCode;
  self.exceptionType = exceptionType;
  self.signal = signal;
  self.applicationVersion = applicationVersion;
  self.metadata = metadata;
  return self;
}

@end
