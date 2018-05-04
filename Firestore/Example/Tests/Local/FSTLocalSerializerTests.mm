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

#import "Firestore/Source/Local/FSTLocalSerializer.h"

#import <FirebaseFirestore/FIRTimestamp.h>
#import <XCTest/XCTest.h>

#import "Firestore/Protos/objc/firestore/local/MaybeDocument.pbobjc.h"
#import "Firestore/Protos/objc/firestore/local/Mutation.pbobjc.h"
#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1beta1/Common.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1beta1/Document.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1beta1/Firestore.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1beta1/Query.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1beta1/Write.pbobjc.h"
#import "Firestore/Protos/objc/google/type/Latlng.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::SnapshotVersion;

NS_ASSUME_NONNULL_BEGIN

@interface FSTSerializerBeta (Test)
- (GCFSValue *)encodedNull;
- (GCFSValue *)encodedBool:(BOOL)value;
- (GCFSValue *)encodedDouble:(double)value;
- (GCFSValue *)encodedInteger:(int64_t)value;
- (GCFSValue *)encodedString:(NSString *)value;
@end

@interface FSTLocalSerializerTests : XCTestCase {
  DatabaseId _databaseId;
}

@property(nonatomic, strong) FSTLocalSerializer *serializer;
@property(nonatomic, strong) FSTSerializerBeta *remoteSerializer;

@end

@implementation FSTLocalSerializerTests

- (void)setUp {
  _databaseId = DatabaseId("p", "d");
  self.remoteSerializer = [[FSTSerializerBeta alloc] initWithDatabaseID:&_databaseId];
  self.serializer = [[FSTLocalSerializer alloc] initWithRemoteSerializer:self.remoteSerializer];
}

- (void)testEncodesMutationBatch {
  FSTMutation *set = FSTTestSetMutation(@"foo/bar", @{ @"a" : @"b", @"num" : @1 });
  FSTMutation *patch = [[FSTPatchMutation alloc] initWithKey:FSTTestDocKey(@"bar/baz")
                                                   fieldMask:FieldMask{testutil::Field("a")}
                                                       value:FSTTestObjectValue(
                                                                 @{ @"a" : @"b",
                                                                    @"num" : @1 })
                                                precondition:Precondition::Exists(true)];
  FSTMutation *del = FSTTestDeleteMutation(@"baz/quux");
  FIRTimestamp *writeTime = [FIRTimestamp timestamp];
  FSTMutationBatch *model = [[FSTMutationBatch alloc] initWithBatchID:42
                                                       localWriteTime:writeTime
                                                            mutations:@[ set, patch, del ]];

  GCFSWrite *setProto = [GCFSWrite message];
  setProto.update.name = @"projects/p/databases/d/documents/foo/bar";
  [setProto.update.fields addEntriesFromDictionary:@{
    @"a" : [self.remoteSerializer encodedString:@"b"],
    @"num" : [self.remoteSerializer encodedInteger:1]
  }];

  GCFSWrite *patchProto = [GCFSWrite message];
  patchProto.update.name = @"projects/p/databases/d/documents/bar/baz";
  [patchProto.update.fields addEntriesFromDictionary:@{
    @"a" : [self.remoteSerializer encodedString:@"b"],
    @"num" : [self.remoteSerializer encodedInteger:1]
  }];
  [patchProto.updateMask.fieldPathsArray addObjectsFromArray:@[ @"a" ]];
  patchProto.currentDocument.exists = YES;

  GCFSWrite *delProto = [GCFSWrite message];
  delProto.delete_p = @"projects/p/databases/d/documents/baz/quux";

  GPBTimestamp *writeTimeProto = [GPBTimestamp message];
  writeTimeProto.seconds = writeTime.seconds;
  writeTimeProto.nanos = writeTime.nanoseconds;

  FSTPBWriteBatch *batchProto = [FSTPBWriteBatch message];
  batchProto.batchId = 42;
  [batchProto.writesArray addObjectsFromArray:@[ setProto, patchProto, delProto ]];
  batchProto.localWriteTime = writeTimeProto;

  XCTAssertEqualObjects([self.serializer encodedMutationBatch:model], batchProto);
  FSTMutationBatch *decoded = [self.serializer decodedMutationBatch:batchProto];
  XCTAssertEqual(decoded.batchID, model.batchID);
  XCTAssertEqualObjects(decoded.localWriteTime, model.localWriteTime);
  XCTAssertEqualObjects(decoded.mutations, model.mutations);
  XCTAssertEqualObjects([decoded keys], [model keys]);
}

- (void)testEncodesDocumentAsMaybeDocument {
  FSTDocument *doc = FSTTestDoc("some/path", 42, @{@"foo" : @"bar"}, NO);

  FSTPBMaybeDocument *maybeDocProto = [FSTPBMaybeDocument message];
  maybeDocProto.document = [GCFSDocument message];
  maybeDocProto.document.name = @"projects/p/databases/d/documents/some/path";
  [maybeDocProto.document.fields addEntriesFromDictionary:@{
    @"foo" : [self.remoteSerializer encodedString:@"bar"],
  }];
  maybeDocProto.document.updateTime.seconds = 0;
  maybeDocProto.document.updateTime.nanos = 42000;

  XCTAssertEqualObjects([self.serializer encodedMaybeDocument:doc], maybeDocProto);
  FSTMaybeDocument *decoded = [self.serializer decodedMaybeDocument:maybeDocProto];
  XCTAssertEqualObjects(decoded, doc);
}

- (void)testEncodesDeletedDocumentAsMaybeDocument {
  FSTDeletedDocument *deletedDoc = FSTTestDeletedDoc("some/path", 42);

  FSTPBMaybeDocument *maybeDocProto = [FSTPBMaybeDocument message];
  maybeDocProto.noDocument = [FSTPBNoDocument message];
  maybeDocProto.noDocument.name = @"projects/p/databases/d/documents/some/path";
  maybeDocProto.noDocument.readTime.seconds = 0;
  maybeDocProto.noDocument.readTime.nanos = 42000;

  XCTAssertEqualObjects([self.serializer encodedMaybeDocument:deletedDoc], maybeDocProto);
  FSTMaybeDocument *decoded = [self.serializer decodedMaybeDocument:maybeDocProto];
  XCTAssertEqualObjects(decoded, deletedDoc);
}

- (void)testEncodesQueryData {
  FSTQuery *query = FSTTestQuery("room");
  FSTTargetID targetID = 42;
  SnapshotVersion version = testutil::Version(1039);
  NSData *resumeToken = FSTTestResumeTokenFromSnapshotVersion(1039);

  FSTQueryData *queryData = [[FSTQueryData alloc] initWithQuery:query
                                                       targetID:targetID
                                           listenSequenceNumber:10
                                                        purpose:FSTQueryPurposeListen
                                                snapshotVersion:version
                                                    resumeToken:resumeToken];

  // Let the RPC serializer test various permutations of query serialization.
  GCFSTarget_QueryTarget *queryTarget = [self.remoteSerializer encodedQueryTarget:query];

  FSTPBTarget *expected = [FSTPBTarget message];
  expected.targetId = targetID;
  expected.lastListenSequenceNumber = 10;
  expected.snapshotVersion.nanos = 1039000;
  expected.resumeToken = [resumeToken copy];
  expected.query.parent = queryTarget.parent;
  expected.query.structuredQuery = queryTarget.structuredQuery;

  XCTAssertEqualObjects([self.serializer encodedQueryData:queryData], expected);
  FSTQueryData *decoded = [self.serializer decodedQueryData:expected];
  XCTAssertEqualObjects(decoded, queryData);
}

@end

NS_ASSUME_NONNULL_END
