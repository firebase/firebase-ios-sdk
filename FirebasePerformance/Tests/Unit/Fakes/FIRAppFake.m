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

#import "FirebasePerformance/Tests/Unit/Fakes/FIRAppFake.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

@implementation FIRAppFake

static dispatch_once_t gDefaultAppToken;

+ (void)reset {
  gDefaultAppToken = 0;
}

+ (FIRAppFake *)defaultApp {
  static FIRAppFake *defaultApp;
  dispatch_once(&gDefaultAppToken, ^{
    FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"" GCMSenderID:@""];
    defaultApp = [[FIRAppFake alloc] initInstanceWithName:@"FPRTesting" options:options];
  });
  return defaultApp;
}

+ (BOOL)isDefaultAppConfigured {
  return YES;
}

- (BOOL)dataCollectionEnabled {
  return _fakeIsDataCollectionDefaultEnabled;
}

- (BOOL)isDataCollectionDefaultEnabled {
  return _fakeIsDataCollectionDefaultEnabled;
}

@end
