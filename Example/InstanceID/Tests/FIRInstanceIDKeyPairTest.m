/*
 * Copyright 2019 Google
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

#import "Firebase/InstanceID/FIRInstanceIDKeyPair.h"
#import "Firebase/InstanceID/FIRInstanceIDKeyPairStore.h"
#import "Firebase/InstanceID/FIRInstanceIDKeyPairUtilities.h"
#import "Firebase/InstanceID/FIRInstanceIDKeychain.h"

static NSString *kKeyPairPrivateTag = @"iid-keypair-test-priv";
static NSString *kKeyPairPublicTag = @"iid-keypair-test-public";

@interface FIRInstanceIDKeyPairStore (ExposedForTest)
+ (void)deleteKeyPairWithPrivateTag:(NSString *)privateTag
                          publicTag:(NSString *)publicTag
                            handler:(void (^)(NSError *))handler;
@end

@interface FIRInstanceIDKeyPairTest : XCTestCase
@end

@implementation FIRInstanceIDKeyPairTest

- (void)testInvalidKeychain {
  FIRInstanceIDKeyPair *keypair = [[FIRInstanceIDKeyPair alloc] initWithPrivateKey:nil
                                                                         publicKey:nil
                                                                     publicKeyData:nil
                                                                    privateKeyData:nil];
  XCTAssertNotNil(keypair);
  XCTAssertFalse([keypair isValid]);
  SecKeyRef publicKeyRef = [keypair publicKey];
  XCTAssertTrue(publicKeyRef == NULL);
  SecKeyRef privateKeyRef = [keypair privateKey];
  XCTAssertTrue(privateKeyRef == NULL);
  XCTAssertNil(keypair.publicKeyData);
  XCTAssertNil(keypair.privateKeyData);
  XCTAssertNil(FIRInstanceIDAppIdentity(keypair));
}

- (void)testValidKeychain {
  FIRInstanceIDKeyPair *keypair =
      [[FIRInstanceIDKeychain sharedInstance] generateKeyPairWithPrivateTag:kKeyPairPrivateTag
                                                                  publicTag:kKeyPairPublicTag];
  XCTAssertNotNil(keypair);
  XCTAssertTrue([keypair isValid]);
  SecKeyRef publicKeyRef = [keypair publicKey];
  XCTAssertFalse(publicKeyRef == NULL);
  SecKeyRef privateKeyRef = [keypair privateKey];
  XCTAssertFalse(privateKeyRef == NULL);
  XCTAssertNotNil(keypair.publicKeyData);
  XCTAssertNotNil(keypair.privateKeyData);
  XCTAssertNotNil(FIRInstanceIDAppIdentity(keypair));

  XCTestExpectation *keyPairDeleted = [self expectationWithDescription:@"keyPairDeleted"];
  [FIRInstanceIDKeyPairStore deleteKeyPairWithPrivateTag:kKeyPairPrivateTag
                                               publicTag:kKeyPairPublicTag
                                                 handler:^(NSError *error) {
                                                   [keyPairDeleted fulfill];
                                                 }];

  [self waitForExpectations:@[ keyPairDeleted ] timeout:1.0];
}
@end
