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

#import <XCTest/XCTest.h>

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "Interop/Auth/Public/FIRAuthInterop.h"

#import "FirebaseDatabase/Sources/FIRDatabaseConfig_Private.h"
#import "FirebaseDatabase/Tests/Helpers/FIRTestAuthTokenProvider.h"
#import "FirebaseDatabase/Tests/Helpers/FTestAuthTokenGenerator.h"
#import "FirebaseDatabase/Tests/Helpers/FTestBase.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"
#import "SharedTestUtilities/FIRAuthInteropFake.h"

@interface FIRAuthTests : FTestBase

@end

@implementation FIRAuthTests

- (void)setUp {
  [super setUp];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testListensAndAuthRaceCondition {
  [FIRDatabase setLoggingEnabled:YES];
  FIRAuthInteropFake *auth = [[FIRAuthInteropFake alloc] initWithToken:nil userID:nil error:nil];
  id<FAuthTokenProvider> authTokenProvider = [FAuthTokenProvider authTokenProviderWithAuth:auth];

  FIRDatabaseConfig *config = [FTestHelpers configForName:@"testWritesRestoredAfterAuth"];
  config.authTokenProvider = authTokenProvider;

  FIRDatabaseReference *ref = [[[FTestHelpers databaseForConfig:config] reference] childByAutoId];

  __block BOOL done = NO;

  [[[ref root] child:@".info/connected"]
      observeEventType:FIRDataEventTypeValue
             withBlock:^void(FIRDataSnapshot *snapshot) {
               if ([snapshot.value boolValue]) {
                 // Start a listen before auth credentials are restored.
                 [ref observeEventType:FIRDataEventTypeValue
                             withBlock:^(FIRDataSnapshot *snapshot){

                             }];

                 // subsequent writes should complete successfully.
                 [ref setValue:@42
                     withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
                       done = YES;
                     }];
               }
             }];

  WAIT_FOR(done);
}
@end
