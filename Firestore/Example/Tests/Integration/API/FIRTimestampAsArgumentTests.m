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

@import FirebaseFirestore;

#import <XCTest/XCTest.h>

#import "FirebaseFirestore/FIRTimestamp.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

@interface FIRTimestampAsArgumentTests : FSTIntegrationTestCase
@end

@implementation FIRTimestampAsArgumentTests

- (NSDictionary<NSString *, id> *)testDataWithTimestamp:(FIRTimestamp *)timestamp {
  return @{
    @"timestamp" : timestamp,
    @"notTimestamp" : @"this is not a timestamp",
    @"metadata" : @{@"nestedTimestamp" : timestamp}
  };
}

- (void)testGetTimestamp {
  FIRTimestamp *timestamp = [FIRTimestamp timestampWithDate:[NSDate date]];
  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:[self testDataWithTimestamp:timestamp]];

  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertEqualObjects([result getTimestamp:@"timestamp"], timestamp);
  XCTAssertEqualObjects([result getTimestamp:@"metadata.nestedTimestamp"], timestamp);
}

- (void)testGetTimestampReturnsNilIfNoField {
  FIRDocumentReference *doc = [self documentRef];
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertNil([result getTimestamp:@"nofield"]);
}

- (void)testGetTimestampThrowsIfWrongType {
  FIRTimestamp *timestamp = [FIRTimestamp timestampWithDate:[NSDate date]];
  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:[self testDataWithTimestamp:timestamp]];

  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertThrows([result getTimestamp:@"notTimestamp"]);
}

- (void)testThatDataContainsNativeDateType {
  NSDate *date = [NSDate date];
  FIRTimestamp *timestamp = [FIRTimestamp timestampWithDate:date];
  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:[self testDataWithTimestamp:timestamp]];

  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  NSDate *resultDate = result.data[@"timestamp"];
  XCTAssertEqualWithAccuracy([resultDate timeIntervalSince1970], [date timeIntervalSince1970],
                             0.000001);
  XCTAssertEqualObjects(result.data[@"timestamp"], resultDate);
  NSDate *resultNestedDate = result[@"metadata.nestedTimestamp"];
  XCTAssertEqualWithAccuracy([resultNestedDate timeIntervalSince1970], [date timeIntervalSince1970],
                             0.000001);
}

- (void)testTimestampsCanBePassedToQueriesAsLimits {
  FIRCollectionReference *testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{@"k" : @"a", @"timestamp" : [FIRTimestamp timestampWithSeconds:100 microseconds:1]},
    @"b" : @{@"k" : @"b", @"timestamp" : [FIRTimestamp timestampWithSeconds:100 microseconds:2]},
    @"c" : @{@"k" : @"c", @"timestamp" : [FIRTimestamp timestampWithSeconds:100 microseconds:3]},
    @"d" : @{@"k" : @"d", @"timestamp" : [FIRTimestamp timestampWithSeconds:100 microseconds:4]},
    @"e" : @{@"k" : @"e", @"timestamp" : [FIRTimestamp timestampWithSeconds:100 microseconds:5]},
    // Number of microseconds deliberately repeated.
    @"f" : @{@"k" : @"f", @"timestamp" : [FIRTimestamp timestampWithSeconds:100 microseconds:5]},
  }];
  FIRQuery *query = [testCollection queryOrderedByField:@"timestamp"];
  FIRQuerySnapshot *querySnapshot =
      [self readDocumentSetForRef:[[query queryStartingAfterValues:@[
              [FIRTimestamp timestampWithSeconds:100 microseconds:2]
            ]] queryEndingAtValues:@[ [FIRTimestamp timestampWithSeconds:100 microseconds:5] ]]];
  NSMutableArray<NSString *> *actual = [NSMutableArray array];
  [querySnapshot.documents enumerateObjectsUsingBlock:^(FIRDocumentSnapshot *_Nonnull doc,
                                                        NSUInteger idx, BOOL *_Nonnull stop) {
    [actual addObject:doc.data[@"k"]];
  }];
  XCTAssertEqualObjects(actual, (@[ @"c", @"d", @"e", @"f" ]));
}

- (void)testTimestampsCanBePassedToQueriesInWhereClause {
  FIRTimestamp *timestamp = [FIRTimestamp timestampWithDate:[NSDate date]];
  FIRCollectionReference *testCollection = [self collectionRefWithDocuments:@{
    @"a" : @{
      @"k" : @"a",
      @"timestamp" : [FIRTimestamp timestampWithSeconds:timestamp.seconds
                                           microseconds:timestamp.microseconds - 1],
    },
    @"b" : @{
      @"k" : @"b",
      @"timestamp" :
          [FIRTimestamp timestampWithSeconds:timestamp.seconds microseconds:timestamp.microseconds],
    },
    @"c" : @{
      @"k" : @"c",
      @"timestamp" : [FIRTimestamp timestampWithSeconds:timestamp.seconds
                                           microseconds:timestamp.microseconds + 1],
    },
    @"d" : @{
      @"k" : @"d",
      @"timestamp" : [FIRTimestamp timestampWithSeconds:timestamp.seconds
                                           microseconds:timestamp.microseconds + 2],
    },
    @"e" : @{
      @"k" : @"e",
      @"timestamp" : [FIRTimestamp timestampWithSeconds:timestamp.seconds
                                           microseconds:timestamp.microseconds + 3],
    }
  }];

  FIRQuerySnapshot *querySnapshot = [self
      readDocumentSetForRef:[[testCollection queryWhereField:@"timestamp"
                                      isGreaterThanOrEqualTo:timestamp]
                                queryWhereField:@"timestamp"
                                     isLessThan:[FIRTimestamp
                                                    timestampWithSeconds:timestamp.seconds
                                                            microseconds:timestamp.microseconds +
                                                                         3]]];
  NSMutableArray<NSString *> *actual = [NSMutableArray array];
  [querySnapshot.documents enumerateObjectsUsingBlock:^(FIRDocumentSnapshot *_Nonnull doc,
                                                        NSUInteger idx, BOOL *_Nonnull stop) {
    [actual addObject:doc.data[@"k"]];
  }];
  XCTAssertEqualObjects(actual, (@[ @"b", @"c", @"d" ]));
}

@end
