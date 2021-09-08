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

#import "FirebasePerformance/Tests/Unit/Configurations/FPRFakeRemoteConfig.h"

@implementation FPRFakeRemoteConfig

- (instancetype)init {
  self = [super init];
  if (self) {
    _configValues = [[NSMutableDictionary<NSString *, FIRRemoteConfigValue *> alloc] init];
  }
  return self;
}

- (BOOL)activateFetchedForNamespace:(NSString *)namespace {
  return YES;
}

- (void)fetchAndActivateWithCompletionHandler:
    (FIRRemoteConfigFetchAndActivateCompletion)completionHandler {
  if (self.fetchStatus != FIRRemoteConfigFetchAndActivateStatusError) {
    self.lastFetchTime = [NSDate date];
    self.lastFetchStatus = FIRRemoteConfigFetchStatusSuccess;
  }
  completionHandler(self.fetchStatus, nil);
}

- (FIRRemoteConfigValue *)configValueForKey:(NSString *)key {
  return [self.configValues objectForKey:key];
}

@end
