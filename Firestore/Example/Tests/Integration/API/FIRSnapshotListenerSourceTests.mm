/*
 * Copyright 2024 Google
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

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Example/Tests/Util/FSTTestingHooks.h"

#import "Firestore/Source/API/FIRAggregateQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"

@interface FIRSnapshotListenerSourceTests : FSTIntegrationTestCase
@end

@implementation FIRSnapshotListenerSourceTests

- (FIRSnapshotListenOptions *)optionsWithSourceFromCache {
    FIRSnapshotListenOptions *options = [[FIRSnapshotListenOptions alloc] init];
    return [options optionsWithSource:FIRListenSourceCache];
}
- (FIRSnapshotListenOptions *)optionsWithSourceFromCacheAndIncludeMetadataChanges {
    FIRSnapshotListenOptions *options = [[FIRSnapshotListenOptions alloc] init];
    return [[options optionsWithSource:FIRListenSourceCache] optionsWithIncludeMetadataChanges:YES];
}

- (void)canRaiseSnapshotFromCacheForQuery {
    FIRCollectionReference *collRef = [self collectionRefWithDocuments:@{
      @"a" : @{@"k" : @"a", @"sort" : @0}
    }];
    
    FIRQuery *query = [collRef queryOrderedByField:@"sort"];
    
    // populate the cache.
    [self readDocumentSetForRef:query];
    
    
    FIRSnapshotListenOptions *optionsFromCache = [self optionsWithSourceFromCache];
    id<FIRListenerRegistration> registration =  [query addSnapshotListenerWithOptions:optionsFromCache  listener:self.eventAccumulator.valueEventHandler];

    FIRQuerySnapshot *querySnap = [self.eventAccumulator awaitEventWithName:@"Snapshot"];
    XCTAssertEqualObjects(FIRQuerySnapshotGetData(querySnap), (@[ @{@"k" : @"a", @"sort" : @1L}]));
    XCTAssertEqual(querySnap.metadata.isFromCache, YES);
    
    [registration remove];
}




@end
