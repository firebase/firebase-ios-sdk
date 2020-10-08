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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import <FirebaseCore/FIRVersion.h>

// The following two macros supply the incantation so that the C
// preprocessor does not try to parse the version as a floating
// point number. See
// https://www.guyrutenberg.com/2008/12/20/expanding-macros-into-string-constants-in-c/
#define STR(x) STR_EXPAND(x)
#define STR_EXPAND(x) #x

@interface VersionTest : XCTestCase
@end

@implementation VersionTest

- (void)testVersion {
  NSString *version = [NSString stringWithUTF8String:(const char *const)STR(FIR_VERSION)];
  XCTAssertEqualObjects(FIRFirebaseVersion(), version);
}

@end
