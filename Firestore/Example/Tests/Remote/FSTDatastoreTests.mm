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

#import "Firestore/Source/Remote/FSTDatastore.h"

#import <FirebaseFirestore/FIRFirestoreErrors.h>
#import <XCTest/XCTest.h>

@interface FSTDatastoreTests : XCTestCase
@end

@implementation FSTDatastoreTests

- (NSError *)errorForCode:(FIRFirestoreErrorCode)code {
  return [NSError errorWithDomain:FIRFirestoreErrorDomain code:code userInfo:nil];
}

- (void)testIsPermanentError {
  // From GRPCCall -cancel
  NSError *error = [NSError errorWithDomain:FIRFirestoreErrorDomain
                                       code:FIRFirestoreErrorCodeCancelled
                                   userInfo:@{NSLocalizedDescriptionKey : @"Canceled by app"}];
  XCTAssertFalse([FSTDatastore isPermanentError:error]);

  // From GRPCCall -startNextRead
  error = [NSError errorWithDomain:FIRFirestoreErrorDomain
                              code:FIRFirestoreErrorCodeResourceExhausted
                          userInfo:@{
                            NSLocalizedDescriptionKey :
                                @"Client does not have enough memory to hold the server response."
                          }];
  XCTAssertFalse([FSTDatastore isPermanentError:error]);

  // From GRPCCall -startWithWriteable
  error = [NSError errorWithDomain:FIRFirestoreErrorDomain
                              code:FIRFirestoreErrorCodeUnavailable
                          userInfo:@{NSLocalizedDescriptionKey : @"Connectivity lost."}];
  XCTAssertFalse([FSTDatastore isPermanentError:error]);

  // User info doesn't matter:
  error = [self errorForCode:FIRFirestoreErrorCodeUnavailable];
  XCTAssertFalse([FSTDatastore isPermanentError:error]);

  // "unauthenticated" is considered a recoverable error due to expired token.
  error = [self errorForCode:FIRFirestoreErrorCodeUnauthenticated];
  XCTAssertFalse([FSTDatastore isPermanentError:error]);

  error = [self errorForCode:FIRFirestoreErrorCodeDataLoss];
  XCTAssertTrue([FSTDatastore isPermanentError:error]);

  error = [self errorForCode:FIRFirestoreErrorCodeAborted];
  XCTAssertTrue([FSTDatastore isPermanentError:error]);
}

- (void)testIsPermanentWriteError {
  NSError *error = [self errorForCode:FIRFirestoreErrorCodeUnauthenticated];
  XCTAssertFalse([FSTDatastore isPermanentWriteError:error]);

  error = [self errorForCode:FIRFirestoreErrorCodeDataLoss];
  XCTAssertTrue([FSTDatastore isPermanentWriteError:error]);

  error = [self errorForCode:FIRFirestoreErrorCodeAborted];
  XCTAssertFalse([FSTDatastore isPermanentWriteError:error]);
}

@end
