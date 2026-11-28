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

// Objective-C API coverage, imported as a module.

#import <XCTest/XCTest.h>

@import FirebaseCore;

#include "FIRCoreAPICoverage.h"

@interface FIRCoreObjCAPIModuleCoverage : XCTestCase
@end

@implementation FIRCoreObjCAPIModuleCoverage

// Compile-only: not prefixed with `test`, so XCTest doesn't run it.
- (void)coverage {
  FIRCoreAPICoverage();
}

@end
