/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseAuth/Tests/Unit/FIRApp+FIRAuthUnitTests.h"

@implementation FIRApp (FIRAuthUnitTests)

/** @fn appOptions
    @brief Gets Firebase app options to be used for tests.
    @return A @c FIROptions instance.
 */
+ (FIROptions *)appOptions {
  return [[FIROptions alloc] initInternalWithOptionsDictionary:@{
    @"GOOGLE_APP_ID" : @"1:1085102361755:ios:f790a919483d5bdf",
    @"API_KEY" : @"FAKE_API_KEY",
    @"GCM_SENDER_ID" : @"217397612173",
    @"CLIENT_ID" : @"123456.apps.googleusercontent.com",
  }];
}

+ (void)resetAppForAuthUnitTests {
  [FIRApp resetApps];
  [FIRApp configureWithOptions:[self appOptions]];
}

+ (FIRApp *)appForAuthUnitTestsWithName:(NSString *)name {
  return [[FIRApp alloc] initInstanceWithName:name options:[self appOptions]];
}

@end
