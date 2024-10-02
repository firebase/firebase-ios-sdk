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

#import <FirebaseFirestore/FirebaseFirestore.h>

#import <XCTest/XCTest.h>

#import "FirebaseCore/Sources/Public/FirebaseCore/FIRTimestamp.h"

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

@interface FIRTypeTests : FSTIntegrationTestCase
@end

@implementation FIRTypeTests

- (void)assertSuccessfulRoundtrip:(NSDictionary *)data {
  FIRDocumentReference *doc = [self.db documentWithPath:@"rooms/eros"];

  [self writeDocumentRef:doc data:data];
  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertTrue(document.exists);
  XCTAssertEqualObjects(document.data, data);
}

- (void)testCanReadAndWriteNullFields {
  [self assertSuccessfulRoundtrip:@{@"a" : @1, @"b" : [NSNull null]}];
}

- (void)testCanReadAndWriteArrayFields {
  [self assertSuccessfulRoundtrip:@{@"array" : @[ @1, @"foo", @{@"deep" : @YES}, [NSNull null] ]}];
}

- (void)testCanReadAndWriteBlobFields {
  NSData *data = [NSData dataWithBytes:"\0\1\2" length:3];
  [self assertSuccessfulRoundtrip:@{@"blob" : data}];
}

- (void)testCanReadAndWriteGeoPointFields {
  [self assertSuccessfulRoundtrip:@{
    @"geoPoint" : [[FIRGeoPoint alloc] initWithLatitude:1.23 longitude:4.56]
  }];
}

- (void)testCanReadAndWriteDateFields {
  // Choose a value that can be converted losslessly between fixed point and double
  NSDate *date = [NSDate dateWithTimeIntervalSince1970:1491847082.125];

  // NSDates are read back as FIRTimestamps, so assertSuccessfulRoundtrip cannot be used here.
  FIRDocumentReference *doc = [self.db documentWithPath:@"rooms/eros"];
  [self writeDocumentRef:doc data:@{@"date" : date}];
  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertTrue(document.exists);
  XCTAssertEqualObjects(document.data, @{@"date" : [FIRTimestamp timestampWithDate:date]});
}

- (void)testCanReadAndWriteTimestampFields {
  // Timestamps are currently truncated to microseconds on the backend, so only be precise to
  // microseconds to ensure the value read back is exactly the same.
  FIRTimestamp *timestamp = [FIRTimestamp timestampWithSeconds:123456 nanoseconds:123456000];
  [self assertSuccessfulRoundtrip:@{@"timestamp" : timestamp}];
}

- (void)testCanReadAndWriteDocumentReferences {
  FIRDocumentReference *docRef = [self documentRef];
  [self assertSuccessfulRoundtrip:@{@"a" : @42, @"ref" : docRef}];
}

- (void)testCanReadAndWriteDocumentReferencesInArrays {
  FIRDocumentReference *docRef = [self documentRef];
  [self assertSuccessfulRoundtrip:@{@"a" : @42, @"refs" : @[ docRef ]}];
}

@end
