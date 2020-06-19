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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "FirebaseDatabase/Sources/Core/FQueryParams.h"
#import "FirebaseDatabase/Sources/FIndex.h"
#import "FirebaseDatabase/Sources/FKeyIndex.h"
#import "FirebaseDatabase/Sources/FPathIndex.h"
#import "FirebaseDatabase/Sources/FPriorityIndex.h"
#import "FirebaseDatabase/Sources/FValueIndex.h"
#import "FirebaseDatabase/Sources/Snapshot/FEmptyNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FLeafNode.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"

@interface FQueryParamsTest : XCTestCase

@end

@implementation FQueryParamsTest

- (void)testQueryParamsEquals {
  {  // Limit equals
    FQueryParams *params1 = [[FQueryParams defaultInstance] limitToLast:10];
    FQueryParams *params2 = [[FQueryParams defaultInstance] limitTo:10];
    FQueryParams *params3 = [[FQueryParams defaultInstance] limitToFirst:10];
    FQueryParams *params4 = [[FQueryParams defaultInstance] limitToLast:11];
    XCTAssertEqualObjects(params1, params2);
    XCTAssertEqual(params1.hash, params2.hash);
    XCTAssertFalse([params1 isEqual:params3]);
    XCTAssertFalse([params1 isEqual:params4]);
  }

  {  // Index equals
    FQueryParams *params1 = [[FQueryParams defaultInstance] orderBy:[FPriorityIndex priorityIndex]];
    FQueryParams *params2 = [[FQueryParams defaultInstance] orderBy:[FPriorityIndex priorityIndex]];
    FQueryParams *params3 = [[FQueryParams defaultInstance] orderBy:[FKeyIndex keyIndex]];
    XCTAssertEqualObjects(params1, params2);
    XCTAssertEqual(params1.hash, params2.hash);
    XCTAssertFalse([params1 isEqual:params3]);
  }

  {  // startAt equals
    FQueryParams *params1 =
        [[FQueryParams defaultInstance] startAt:[FSnapshotUtilities nodeFrom:@"value"]];
    FQueryParams *params2 =
        [[FQueryParams defaultInstance] startAt:[FSnapshotUtilities nodeFrom:@"value"]
                                       childKey:nil];
    FQueryParams *params3 =
        [[FQueryParams defaultInstance] startAt:[FSnapshotUtilities nodeFrom:@"value-2"]];
    XCTAssertEqualObjects(params1, params2);
    XCTAssertEqual(params1.hash, params2.hash);
    XCTAssertFalse([params1 isEqual:params3]);
  }

  {  // startAt with childkey equals
    FQueryParams *params1 = [[FQueryParams defaultInstance] startAt:[FEmptyNode emptyNode]
                                                           childKey:@"key"];
    FQueryParams *params2 = [[FQueryParams defaultInstance] startAt:[FEmptyNode emptyNode]
                                                           childKey:@"key"];
    FQueryParams *params3 = [[FQueryParams defaultInstance] startAt:[FEmptyNode emptyNode]
                                                           childKey:@"other-key"];
    XCTAssertEqualObjects(params1, params2);
    XCTAssertEqual(params1.hash, params2.hash);
    XCTAssertFalse([params1 isEqual:params3]);
  }

  {  // endAt equals
    FQueryParams *params1 =
        [[FQueryParams defaultInstance] endAt:[FSnapshotUtilities nodeFrom:@"value"]];
    FQueryParams *params2 =
        [[FQueryParams defaultInstance] endAt:[FSnapshotUtilities nodeFrom:@"value"] childKey:nil];
    FQueryParams *params3 =
        [[FQueryParams defaultInstance] endAt:[FSnapshotUtilities nodeFrom:@"value-2"]];
    XCTAssertEqualObjects(params1, params2);
    XCTAssertEqual(params1.hash, params2.hash);
    XCTAssertFalse([params1 isEqual:params3]);
  }

  {  // endAt with childkey equals
    FQueryParams *params1 = [[FQueryParams defaultInstance] endAt:[FEmptyNode emptyNode]
                                                         childKey:@"key"];
    FQueryParams *params2 = [[FQueryParams defaultInstance] endAt:[FEmptyNode emptyNode]
                                                         childKey:@"key"];
    FQueryParams *params3 = [[FQueryParams defaultInstance] endAt:[FEmptyNode emptyNode]
                                                         childKey:@"other-key"];
    XCTAssertEqualObjects(params1, params2);
    XCTAssertEqual(params1.hash, params2.hash);
    XCTAssertFalse([params1 isEqual:params3]);
  }

  {  // Limit/startAt equals
    FQueryParams *params1 = [[[FQueryParams defaultInstance] limitToFirst:10]
        startAt:[FSnapshotUtilities nodeFrom:@"value"]];
    FQueryParams *params2 = [[[FQueryParams defaultInstance] limitTo:10]
        startAt:[FSnapshotUtilities nodeFrom:@"value"]];
    FQueryParams *params3 = [[[FQueryParams defaultInstance] limitTo:10]
        startAt:[FSnapshotUtilities nodeFrom:@"value-2"]];
    XCTAssertEqualObjects(params1, params2);
    XCTAssertEqual(params1.hash, params2.hash);
    XCTAssertFalse([params1 isEqual:params3]);
  }
}

- (void)testFromDictionaryEquals {
  FQueryParams *params1 = [[[[[FQueryParams defaultInstance] limitToLast:10]
       startAt:[FSnapshotUtilities nodeFrom:@"start-value"]
      childKey:@"child-key-2"] endAt:[FSnapshotUtilities nodeFrom:@"end-value"]
                            childKey:@"child-key-2"] orderBy:[FKeyIndex keyIndex]];
  XCTAssertEqualObjects(params1, [FQueryParams fromQueryObject:params1.wireProtocolParams]);
  XCTAssertEqual(params1.hash, [FQueryParams fromQueryObject:params1.wireProtocolParams].hash);
}

- (void)testCanCreateAllIndexes {
  FQueryParams *params1 = [[FQueryParams defaultInstance] orderBy:[FKeyIndex keyIndex]];
  FQueryParams *params2 = [[FQueryParams defaultInstance] orderBy:[FValueIndex valueIndex]];
  FQueryParams *params3 = [[FQueryParams defaultInstance] orderBy:[FPriorityIndex priorityIndex]];
  FQueryParams *params4 = [[FQueryParams defaultInstance]
      orderBy:[[FPathIndex alloc] initWithPath:[[FPath alloc] initWith:@"subkey"]]];
  XCTAssertEqualObjects(params1, [FQueryParams fromQueryObject:params1.wireProtocolParams]);
  XCTAssertEqualObjects(params2, [FQueryParams fromQueryObject:params2.wireProtocolParams]);
  XCTAssertEqualObjects(params3, [FQueryParams fromQueryObject:params3.wireProtocolParams]);
  XCTAssertEqualObjects(params4, [FQueryParams fromQueryObject:params4.wireProtocolParams]);
  XCTAssertEqual(params1.hash, [FQueryParams fromQueryObject:params1.wireProtocolParams].hash);
  XCTAssertEqual(params2.hash, [FQueryParams fromQueryObject:params2.wireProtocolParams].hash);
  XCTAssertEqual(params3.hash, [FQueryParams fromQueryObject:params3.wireProtocolParams].hash);
  XCTAssertEqual(params4.hash, [FQueryParams fromQueryObject:params4.wireProtocolParams].hash);
}

- (void)testDifferentLimits {
  FQueryParams *params1 = [[FQueryParams defaultInstance] limitToFirst:10];
  FQueryParams *params2 = [[FQueryParams defaultInstance] limitToLast:10];
  FQueryParams *params3 = [[FQueryParams defaultInstance] limitTo:10];
  XCTAssertEqualObjects(params1, [FQueryParams fromQueryObject:params1.wireProtocolParams]);
  XCTAssertEqualObjects(params2, [FQueryParams fromQueryObject:params2.wireProtocolParams]);
  XCTAssertEqualObjects(params3, [FQueryParams fromQueryObject:params3.wireProtocolParams]);
  // 2 and 3 are equivalent
  XCTAssertEqualObjects(params2, [FQueryParams fromQueryObject:params3.wireProtocolParams]);

  XCTAssertEqual(params1.hash, [FQueryParams fromQueryObject:params1.wireProtocolParams].hash);
  XCTAssertEqual(params2.hash, [FQueryParams fromQueryObject:params2.wireProtocolParams].hash);
  XCTAssertEqual(params3.hash, [FQueryParams fromQueryObject:params3.wireProtocolParams].hash);
  // 2 and 3 are equivalent
  XCTAssertEqual(params2.hash, [FQueryParams fromQueryObject:params3.wireProtocolParams].hash);
}

- (void)testStartAtNullIsSerializable {
  FQueryParams *params = [FQueryParams defaultInstance];
  params = [params startAt:[FEmptyNode emptyNode] childKey:@"key"];
  NSDictionary *dict = [params wireProtocolParams];
  FQueryParams *parsed = [FQueryParams fromQueryObject:dict];
  XCTAssertEqualObjects(parsed, params);
  XCTAssertTrue([parsed hasStart]);
}

- (void)testEndAtNullIsSerializable {
  FQueryParams *params = [FQueryParams defaultInstance];
  params = [params endAt:[FEmptyNode emptyNode] childKey:@"key"];
  NSDictionary *dict = [params wireProtocolParams];
  FQueryParams *parsed = [FQueryParams fromQueryObject:dict];
  XCTAssertEqualObjects(parsed, params);
  XCTAssertTrue([parsed hasEnd]);
}

@end
