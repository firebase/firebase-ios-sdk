// Copyright 2023 Google LLC
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

// This file imports all Firebase products that vend an umbrella header.
// Products implemented in Swift are therefore omitted.

// ‼️ NOTE: Changes should also be reflected in `objcxx-header-import-test.m`.

#import <Firebase.h>
#import <FirebaseABTesting/FirebaseABTesting.h>
#import <FirebaseAnalytics/FirebaseAnalytics.h>
#import <FirebaseAuth/FirebaseAuth.h>
#import <FirebaseCore/FirebaseCore.h>
#import "Firebase.h"
#import "FirebaseABTesting/FirebaseABTesting.h"
#import "FirebaseAnalytics/FirebaseAnalytics.h"
#import "FirebaseAuth/FirebaseAuth.h"
#import "FirebaseCore/FirebaseCore.h"
#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_TV
#import <FirebaseInAppMessaging/FirebaseInAppMessaging.h>
#import "FirebaseInAppMessaging/FirebaseInAppMessaging.h"
#endif
#ifdef COCOAPODS
#import "FirebaseStorage/FIRStorageTypedefs.h"

@interface TestImports : NSObject
@end

@implementation TestImports
- (FIRAuth *)testImports {
  return [FIRAuth auth];
}
@end
#endif
