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

#import "Firestore/Source/Local/FSTRemoteDocumentChangeBuffer.h"

#import <XCTest/XCTest.h>

#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTRemoteDocumentCache.h"
#import "Firestore/Source/Model/FSTDocument.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTRemoteDocumentChangeBufferTests : XCTestCase
@end

@implementation FSTRemoteDocumentChangeBufferTests {
  FSTLevelDB *_db;
  id<FSTRemoteDocumentCache> _remoteDocumentCache;
  FSTRemoteDocumentChangeBuffer *_remoteDocumentBuffer;

  FSTMaybeDocument *_kInitialADoc;
  FSTMaybeDocument *_kInitialBDoc;
}

- (void)setUp {
  [super setUp];

  _db = [FSTPersistenceTestHelpers levelDBPersistence];
  _remoteDocumentCache = [_db remoteDocumentCache];

  // Add a couple initial items to the cache.
  FSTWriteGroup *group = [_db startGroupWithAction:@"Add initial docs."];
  _kInitialADoc = FSTTestDoc("coll/a", 42, @{@"test" : @"data"}, NO);
  [_remoteDocumentCache addEntry:_kInitialADoc group:group];

  _kInitialBDoc =
      [FSTDeletedDocument documentWithKey:FSTTestDocKey(@"coll/b") version:FSTTestVersion(314)];
  [_remoteDocumentCache addEntry:_kInitialBDoc group:group];
  [_db commitGroup:group];

  _remoteDocumentBuffer =
      [FSTRemoteDocumentChangeBuffer changeBufferWithCache:_remoteDocumentCache];
}

- (void)tearDown {
  _remoteDocumentBuffer = nil;
  _remoteDocumentCache = nil;
  _db = nil;

  [super tearDown];
}

- (void)testReadUnchangedEntry {
  XCTAssertEqualObjects([_remoteDocumentBuffer entryForKey:FSTTestDocKey(@"coll/a")],
                        _kInitialADoc);
}

- (void)testAddEntryAndReadItBack {
  FSTMaybeDocument *newADoc = FSTTestDoc("coll/a", 43, @{@"new" : @"data"}, NO);
  [_remoteDocumentBuffer addEntry:newADoc];
  XCTAssertEqualObjects([_remoteDocumentBuffer entryForKey:FSTTestDocKey(@"coll/a")], newADoc);

  // B should still be unchanged.
  XCTAssertEqualObjects([_remoteDocumentBuffer entryForKey:FSTTestDocKey(@"coll/b")],
                        _kInitialBDoc);
}

- (void)testApplyChanges {
  FSTMaybeDocument *newADoc = FSTTestDoc("coll/a", 43, @{@"new" : @"data"}, NO);
  [_remoteDocumentBuffer addEntry:newADoc];
  XCTAssertEqualObjects([_remoteDocumentBuffer entryForKey:FSTTestDocKey(@"coll/a")], newADoc);

  // Reading directly against the cache should still yield the old result.
  XCTAssertEqualObjects([_remoteDocumentCache entryForKey:FSTTestDocKey(@"coll/a")], _kInitialADoc);

  FSTWriteGroup *group = [_db startGroupWithAction:@"Apply changes"];
  [_remoteDocumentBuffer applyToWriteGroup:group];
  [_db commitGroup:group];

  // Reading against the cache should now yield the new result.
  XCTAssertEqualObjects([_remoteDocumentCache entryForKey:FSTTestDocKey(@"coll/a")], newADoc);
}

- (void)testMethodsThrowAfterApply {
  FSTWriteGroup *group = [_db startGroupWithAction:@"Apply changes"];
  [_remoteDocumentBuffer applyToWriteGroup:group];
  [_db commitGroup:group];

  XCTAssertThrows([_remoteDocumentBuffer entryForKey:FSTTestDocKey(@"coll/a")]);
  XCTAssertThrows([_remoteDocumentBuffer addEntry:_kInitialADoc]);
  XCTAssertThrows([_remoteDocumentBuffer applyToWriteGroup:group]);
}

@end

NS_ASSUME_NONNULL_END
