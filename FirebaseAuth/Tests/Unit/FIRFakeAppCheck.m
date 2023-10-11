/*
 * Copyright 2023 Google LLC
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
#import "FirebaseAuth/Tests/Unit/FIRFakeAppCheck.h"

#import <Foundation/Foundation.h>

#import <FirebaseAppCheckInterop/FirebaseAppCheckInterop.h>

#pragma mark - FIRFakeAppCheckResult

/// A fake appCheckResult used for dependency injection during testing.
@interface FIRFakeAppCheckResult : NSObject <FIRAppCheckTokenResultInterop>
@property(nonatomic) NSString *token;
@property(nonatomic, nullable) NSError *error;
@end

@implementation FIRFakeAppCheckResult

@end

@implementation FIRFakeAppCheck

- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(nonnull FIRAppCheckTokenHandlerInterop)completion {
  FIRFakeAppCheckResult *fakeAppCheckResult = [[FIRFakeAppCheckResult alloc] init];
  fakeAppCheckResult.token = kFakeAppCheckToken;
  completion(fakeAppCheckResult);
}

@end
