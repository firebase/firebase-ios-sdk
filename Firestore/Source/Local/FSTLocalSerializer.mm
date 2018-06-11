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

#include <cinttypes>

#import "FIRTimestamp.h"
#import "Firestore/Protos/objc/firestore/local/MaybeDocument.pbobjc.h"
#import "Firestore/Protos/objc/firestore/local/Mutation.pbobjc.h"
#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1beta1/Document.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

using firebase::Timestamp;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::SnapshotVersion;

@interface FSTLocalSerializer ()

@property(nonatomic, strong, readonly) FSTSerializerBeta *remoteSerializer;

@end

/** Serializer for values stored in the LocalStore. */
@implementation FSTLocalSerializer

- (instancetype)initWithRemoteSerializer:(FSTSerializerBeta *)remoteSerializer {
  self = [super init];
  if (self) {
    _remoteSerializer = remoteSerializer;
  }
  return self;
}

- (FSTPBMaybeDocument *)encodedMaybeDocument:(FSTMaybeDocument *)document {
  FSTPBMaybeDocument *proto = [FSTPBMaybeDocument message];

  if ([document isKindOfClass:[FSTDeletedDocument class]]) {
    proto.noDocument = [self encodedDeletedDocument:(FSTDeletedDocument *)document];
  } else if ([document isKindOfClass:[FSTDocument class]]) {
    proto.document = [self encodedDocument:(FSTDocument *)document];
  } else {
    HARD_FAIL("Unknown document type %s", NSStringFromClass([document class]));
  }

  return proto;
}

- (FSTMaybeDocument *)decodedMaybeDocument:(FSTPBMaybeDocument *)proto {
  switch (proto.documentTypeOneOfCase) {
    case FSTPBMaybeDocument_DocumentType_OneOfCase_Document:
      return [self decodedDocument:proto.document];

    case FSTPBMaybeDocument_DocumentType_OneOfCase_NoDocument:
      return [self decodedDeletedDocument:proto.noDocument];

    default:
      HARD_FAIL("Unknown MaybeDocument %s", proto);
  }
}

/**
 * Encodes a Document for local storage. This differs from the v1beta1 RPC serializer for
 * Documents in that it preserves the updateTime, which is considered an output only value by the
 * server.
 */
- (GCFSDocument *)encodedDocument:(FSTDocument *)document {
  FSTSerializerBeta *remoteSerializer = self.remoteSerializer;

  GCFSDocument *proto = [GCFSDocument message];
  proto.name = [remoteSerializer encodedDocumentKey:document.key];
  proto.fields = [remoteSerializer encodedFields:document.data];
  proto.updateTime = [remoteSerializer encodedVersion:document.version];

  return proto;
}

/** Decodes a Document proto to the equivalent model. */
- (FSTDocument *)decodedDocument:(GCFSDocument *)document {
  FSTSerializerBeta *remoteSerializer = self.remoteSerializer;

  FSTObjectValue *data = [remoteSerializer decodedFields:document.fields];
  DocumentKey key = [remoteSerializer decodedDocumentKey:document.name];
  SnapshotVersion version = [remoteSerializer decodedVersion:document.updateTime];
  return [FSTDocument documentWithData:data key:key version:version hasLocalMutations:NO];
}

/** Encodes a NoDocument value to the equivalent proto. */
- (FSTPBNoDocument *)encodedDeletedDocument:(FSTDeletedDocument *)document {
  FSTSerializerBeta *remoteSerializer = self.remoteSerializer;

  FSTPBNoDocument *proto = [FSTPBNoDocument message];
  proto.name = [remoteSerializer encodedDocumentKey:document.key];
  proto.readTime = [remoteSerializer encodedVersion:document.version];
  return proto;
}

/** Decodes a NoDocument proto to the equivalent model. */
- (FSTDeletedDocument *)decodedDeletedDocument:(FSTPBNoDocument *)proto {
  FSTSerializerBeta *remoteSerializer = self.remoteSerializer;

  DocumentKey key = [remoteSerializer decodedDocumentKey:proto.name];
  SnapshotVersion version = [remoteSerializer decodedVersion:proto.readTime];
  return [FSTDeletedDocument documentWithKey:key version:version];
}

- (FSTPBWriteBatch *)encodedMutationBatch:(FSTMutationBatch *)batch {
  FSTSerializerBeta *remoteSerializer = self.remoteSerializer;

  FSTPBWriteBatch *proto = [FSTPBWriteBatch message];
  proto.batchId = batch.batchID;
  proto.localWriteTime = [remoteSerializer
      encodedTimestamp:Timestamp{batch.localWriteTime.seconds, batch.localWriteTime.nanoseconds}];

  NSMutableArray<GCFSWrite *> *writes = proto.writesArray;
  for (FSTMutation *mutation in batch.mutations) {
    [writes addObject:[remoteSerializer encodedMutation:mutation]];
  }
  return proto;
}

- (FSTMutationBatch *)decodedMutationBatch:(FSTPBWriteBatch *)batch {
  FSTSerializerBeta *remoteSerializer = self.remoteSerializer;

  int batchID = batch.batchId;
  NSMutableArray<FSTMutation *> *mutations = [NSMutableArray array];
  for (GCFSWrite *write in batch.writesArray) {
    [mutations addObject:[remoteSerializer decodedMutation:write]];
  }

  Timestamp localWriteTime = [remoteSerializer decodedTimestamp:batch.localWriteTime];

  return [[FSTMutationBatch alloc]
      initWithBatchID:batchID
       localWriteTime:[FIRTimestamp timestampWithSeconds:localWriteTime.seconds()
                                             nanoseconds:localWriteTime.nanoseconds()]
            mutations:mutations];
}

- (FSTPBTarget *)encodedQueryData:(FSTQueryData *)queryData {
  FSTSerializerBeta *remoteSerializer = self.remoteSerializer;

  HARD_ASSERT(queryData.purpose == FSTQueryPurposeListen,
              "only queries with purpose %s may be stored, got %s", FSTQueryPurposeListen,
              queryData.purpose);

  FSTPBTarget *proto = [FSTPBTarget message];
  proto.targetId = queryData.targetID;
  proto.lastListenSequenceNumber = queryData.sequenceNumber;
  proto.snapshotVersion = [remoteSerializer encodedVersion:queryData.snapshotVersion];
  proto.resumeToken = queryData.resumeToken;

  FSTQuery *query = queryData.query;
  if ([query isDocumentQuery]) {
    proto.documents = [remoteSerializer encodedDocumentsTarget:query];
  } else {
    proto.query = [remoteSerializer encodedQueryTarget:query];
  }

  return proto;
}

- (FSTQueryData *)decodedQueryData:(FSTPBTarget *)target {
  FSTSerializerBeta *remoteSerializer = self.remoteSerializer;

  FSTTargetID targetID = target.targetId;
  FSTListenSequenceNumber sequenceNumber = target.lastListenSequenceNumber;
  SnapshotVersion version = [remoteSerializer decodedVersion:target.snapshotVersion];
  NSData *resumeToken = target.resumeToken;

  FSTQuery *query;
  switch (target.targetTypeOneOfCase) {
    case FSTPBTarget_TargetType_OneOfCase_Documents:
      query = [remoteSerializer decodedQueryFromDocumentsTarget:target.documents];
      break;

    case FSTPBTarget_TargetType_OneOfCase_Query:
      query = [remoteSerializer decodedQueryFromQueryTarget:target.query];
      break;

    default:
      HARD_FAIL("Unknown Target.targetType %s", target.targetTypeOneOfCase);
  }

  return [[FSTQueryData alloc] initWithQuery:query
                                    targetID:targetID
                        listenSequenceNumber:sequenceNumber
                                     purpose:FSTQueryPurposeListen
                             snapshotVersion:version
                                 resumeToken:resumeToken];
}

- (GPBTimestamp *)encodedVersion:(const SnapshotVersion &)version {
  return [self.remoteSerializer encodedVersion:version];
}

- (SnapshotVersion)decodedVersion:(GPBTimestamp *)version {
  return [self.remoteSerializer decodedVersion:version];
}

@end
