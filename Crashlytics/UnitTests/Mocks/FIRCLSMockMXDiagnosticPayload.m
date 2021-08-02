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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXDiagnosticPayload.h"

@implementation FIRCLSMockMXDiagnosticPayload

- (instancetype)initWithDiagnostics:(NSDictionary *)diagnostics
                     timeStampBegin:(NSDate *)timeStampBegin
                       timeStampEnd:(NSDate *)timeStampEnd
                 applicationVersion:(NSString *)applicationVersion {
  self.timeStampBegin = timeStampBegin;
  self.timeStampEnd = timeStampEnd;
  self.crashDiagnostics = [diagnostics objectForKey:@"crashes"];
  self.hangDiagnostics = [diagnostics objectForKey:@"hangs"];
  self.cpuExceptionDiagnostics = [diagnostics objectForKey:@"cpuExceptionDiagnostics"];
  self.diskWriteExceptionDiagnostics = [diagnostics objectForKey:@"diskWriteExceptionDiagnostics"];
  return self;
}

@end
