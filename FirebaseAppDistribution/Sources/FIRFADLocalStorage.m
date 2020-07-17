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
#import "FIRFADLocalStorage+Private.h"
#import "GoogleUtilities/UserDefaults/Private/GULUserDefaults.h"

static NSString *const kFIRFADSignInStateKey = @"FIRFADSignInState";
@implementation FIRFADLocalStorage

+ (BOOL)isTesterSignedIn {
  return [[GULUserDefaults standardUserDefaults] boolForKey:kFIRFADSignInStateKey];
}

+ (void)registerSignIn {
  [[GULUserDefaults standardUserDefaults] setBool:YES forKey:kFIRFADSignInStateKey];
}

+ (void)registerSignOut {
  [[GULUserDefaults standardUserDefaults] setBool:NO forKey:kFIRFADSignInStateKey];
}

@end
