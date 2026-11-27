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

// Objective-C API coverage using bare-name quoted includes, the way firebase-cpp-sdk includes
// FirebaseCore: it adds FirebaseCore/Sources/Public/FirebaseCore to its header search path. The
// test target's cSettings add the same directory, so these headers must stay at that path.

#import <XCTest/XCTest.h>

#import "FIRApp.h"
#import "FIRConfiguration.h"
#import "FIRLoggerLevel.h"
#import "FIROptions.h"
#import "FIRTimestamp.h"
#import "FIRVersion.h"
#import "FirebaseCore.h"

#include "FIRCoreAPICoverage.h"

@interface FIRCoreObjCAPIBareNameCoverage : XCTestCase
@end

@implementation FIRCoreObjCAPIBareNameCoverage

// Compile-only: not prefixed with `test`, so XCTest doesn't run it.
- (void)coverage {
  FIRCoreAPICoverage();
}

@end
