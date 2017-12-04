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

#import "FirebaseFirestore/FIRQuery.h"

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRQueryTests : XCTestCase
@end

@implementation FIRQueryTests

- (void)testEquals {
    FIRQuery *query1 = [FIRQuery alloc];
    FIRQuery *query2 = [FIRQuery alloc];
    XCTAssertEqualObjects(query1, query2);
}

@end

NS_ASSUME_NONNULL_END
