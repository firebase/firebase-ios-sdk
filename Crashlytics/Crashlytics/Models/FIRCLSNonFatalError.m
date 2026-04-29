// Copyright 2026 Google LLC
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

#import "Crashlytics/Crashlytics/Models/FIRCLSNonFatalError.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSUserLogging.h"

@implementation FIRCLSNonFatalError

- (instancetype)initWithError:(NSError *)error
                     userInfo:(NSDictionary<NSString *, id> *)userInfo
             rolloutsInfoJSON:(NSString *)rolloutsInfoJSON {
  if (!error) {
    return nil;
  }

  self = [super init];
  if (self) {
    _error = error;
    _userInfo = userInfo;
    _rolloutsInfoJSON = rolloutsInfoJSON;
    // Take a snapshot of the thread at initialization.
    _stackTrace = [NSThread callStackReturnAddresses];
    _timestamp = time(NULL);
  }
  return self;
}

- (void)recordError {
  FIRCLSUserLoggingRecordError(self.error, self.userInfo, self.rolloutsInfoJSON, self.stackTrace,
                               self.timestamp);
}
