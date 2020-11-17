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

#import <XCTest/XCTest.h>

#import "Crashlytics/Shared/FIRCLSConstants.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#define STR_HELPER(x) #x
#define STR(x) STR_HELPER(x)

@interface FIRCLSConstantsTest : XCTestCase

@end

@implementation FIRCLSConstantsTest

- (void)testGeneratorName {
  NSString *expectedGeneratorName =
      [NSString stringWithFormat:@"%s/%s", STR(CLS_SDK_NAME), FIRCLSSDKVersion().UTF8String];
  XCTAssertEqualObjects(expectedGeneratorName, FIRCLSSDKGeneratorName());
}

- (void)testSdkVersion {
#ifdef CRASHLYTICS_1P
  NSString *expectedSdkVersion = [FIRFirebaseVersion() stringByAppendingString:@"_1P"];
#else
  NSString *expectedSdkVersion = FIRFirebaseVersion();
#endif
  XCTAssertEqualObjects(expectedSdkVersion, FIRCLSSDKVersion());
}

@end
