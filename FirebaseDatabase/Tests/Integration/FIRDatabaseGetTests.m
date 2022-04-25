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

#import "FirebaseDatabase/Tests/Integration/FIRDatabaseGetTests.h"
#import "FirebaseCore/Sources/Public/FirebaseCore/FIROptions.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Core/FQuerySpec.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"
#import "FirebaseDatabase/Tests/Helpers/FIRFakeApp.h"
#import "FirebaseDatabase/Tests/Helpers/FTestExpectations.h"

@implementation FIRDatabaseGetTests

- (void)testTest {
    FIRDatabaseReference* ref = [FTestHelpers getRandomNode];
    FIRDatabaseReference* root = [ref root];
    
    __block BOOL removeDone = NO;
    [root removeValueWithCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
      removeDone = YES;
    }];
    WAIT_FOR(removeDone);
}

@end
