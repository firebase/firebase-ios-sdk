/*
 * Copyright 2022 Google LLC
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

#import "FIRAggregateSource.h"
#import "FIRAggregateQuery.h"
#import "FIRAggregateQuerySnapshot.h"
#import "FIRDocumentSnapshot.h"
#import "FIRCollectionReference.h"
#import "FIRFirestore.h"
#import "FIRQuery.h"
#import "FIRQuerySnapshot.h"

@interface FIRAggregateDemo : XCTestCase
@end

@implementation FIRAggregateDemo

- (void)Demo0_NormalQuery:(FIRFirestore *)db {
  FIRCollectionReference* query = [db collectionWithPath:@"games/halo/players"];
  [query getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *) {
    XCTAssertEqual(snapshot.count, 5000000);
    XCTAssertEqual([snapshot.documents[0] valueForField:@"name"], @"0player");
  }];
}

- (void)Demo1_CountOfDocumentsInACollection:(FIRFirestore *)db {
  FIRCollectionReference* collection = [db collectionWithPath:@"games/halo/players"];
  [collection.countAggregateQuery aggregationWithSource:FIRAggregateSourceServerDirect
      completion:^(FIRAggregateQuerySnapshot *snapshot, NSError *) {
        XCTAssertEqual([snapshot count].intValue, 5000000);
      }
  ];
}

- (void)Demo2_CountOfDocumentsInACollectionWithFilter:(FIRFirestore *)db {
  FIRCollectionReference* collection = [db collectionWithPath:@"games/halo/players"];
  FIRQuery* query = [collection queryWhereField:@"online" isEqualTo:@YES];
  [query.countAggregateQuery aggregationWithSource:FIRAggregateSourceServerDirect
      completion:^(FIRAggregateQuerySnapshot *snapshot, NSError *) {
        XCTAssertEqual([snapshot count].intValue, 2000);
      }
  ];
}

- (void)Demo3_CountOfDocumentsInACollectionWithLimit:(FIRFirestore *)db {
  FIRCollectionReference* collection = [db collectionWithPath:@"games/halo/players"];
  FIRQuery* query = [collection queryLimitedTo:9000];
  [query.countAggregateQuery aggregationWithSource:FIRAggregateSourceServerDirect
      completion:^(FIRAggregateQuerySnapshot *snapshot, NSError *) {
        XCTAssertEqual([snapshot count].intValue, 9000);
      }
  ];
}

@end
