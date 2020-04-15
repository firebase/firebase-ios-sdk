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

#import "FirebaseAuth/Sources/User/FIRUserMetadata_Internal.h"

/** @var kCreationDateInSeconds
    @brief The fake creation date.
 */
static NSTimeInterval const kCreationDateTimeIntervalInSeconds = 1505858500;

/** @var kLastSignInDateTimeIntervalInSeconds
    @brief The fake last sign in date date.
 */
static NSTimeInterval const kLastSignInDateTimeIntervalInSeconds = 1505858583;

/** @class FIRUserMetadataTests
    @brief Tests for @c FIRUserMetadata.
 */
@interface FIRUserMetadataTests : XCTestCase

@end

@implementation FIRUserMetadataTests

/** @fn testUserMetadataCreation
    @brief Tests succuessful creation of a @c FIRUserMetadata object.
 */
- (void)testUserMetadataCreation {
  NSDate *creationDate = [NSDate dateWithTimeIntervalSince1970:kCreationDateTimeIntervalInSeconds];
  NSDate *lastSignInDate =
      [NSDate dateWithTimeIntervalSince1970:kLastSignInDateTimeIntervalInSeconds];
  FIRUserMetadata *userMetadata = [[FIRUserMetadata alloc] initWithCreationDate:creationDate
                                                                 lastSignInDate:lastSignInDate];
  XCTAssertEqualObjects(userMetadata.creationDate, creationDate);
  XCTAssertEqualObjects(userMetadata.lastSignInDate, lastSignInDate);
}

/** @fn testUserMetadataCoding
    @brief Tests succuessful archiving and unarchiving of a @c FIRUserMetadata object.
 */
- (void)testUserMetadataCoding {
  NSDate *creationDate = [NSDate dateWithTimeIntervalSince1970:kCreationDateTimeIntervalInSeconds];
  NSDate *lastSignInDate =
      [NSDate dateWithTimeIntervalSince1970:kLastSignInDateTimeIntervalInSeconds];
  FIRUserMetadata *userMetadata = [[FIRUserMetadata alloc] initWithCreationDate:creationDate
                                                                 lastSignInDate:lastSignInDate];
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:userMetadata];
  XCTAssertNotNil(data, @"Should not be nil if archving succeeded.");
  XCTAssertNoThrow([NSKeyedUnarchiver unarchiveObjectWithData:data],
                   @"Unarchiving should not throw an exception");
  FIRUserMetadata *unArchivedUserMetadata = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  XCTAssertTrue([unArchivedUserMetadata isKindOfClass:[FIRUserMetadata class]]);
  XCTAssertEqualObjects(unArchivedUserMetadata.creationDate, creationDate);
  XCTAssertEqualObjects(unArchivedUserMetadata.lastSignInDate, lastSignInDate);
}

@end
