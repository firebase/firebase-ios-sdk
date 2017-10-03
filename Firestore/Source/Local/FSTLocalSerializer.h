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

@class FSTMaybeDocument;
@class FSTMutationBatch;
@class FSTQueryData;
@class FSTSerializerBeta;
@class FSTSnapshotVersion;

@class FSTPBMaybeDocument;
@class FSTPBTarget;
@class FSTPBWriteBatch;

@class GPBTimestamp;

NS_ASSUME_NONNULL_BEGIN

/**
 * Serializer for values stored in the LocalStore.
 *
 * Note that FSTLocalSerializer currently delegates to the serializer for the Firestore v1beta1 RPC
 * protocol to save implementation time and code duplication. We'll need to revisit this when the
 * RPC protocol we use diverges from local storage.
 */
@interface FSTLocalSerializer : NSObject

- (instancetype)initWithRemoteSerializer:(FSTSerializerBeta *)remoteSerializer;

- (instancetype)init NS_UNAVAILABLE;

/** Encodes an FSTMaybeDocument model to the equivalent protocol buffer for local storage. */
- (FSTPBMaybeDocument *)encodedMaybeDocument:(FSTMaybeDocument *)document;

/** Decodes an FSTPBMaybeDocument proto to the equivalent model. */
- (FSTMaybeDocument *)decodedMaybeDocument:(FSTPBMaybeDocument *)proto;

/** Encodes an FSTMutationBatch model for local storage in the mutation queue. */
- (FSTPBWriteBatch *)encodedMutationBatch:(FSTMutationBatch *)batch;

/** Decodes an FSTPBWriteBatch proto into a MutationBatch model. */
- (FSTMutationBatch *)decodedMutationBatch:(FSTPBWriteBatch *)batch;

/** Encodes an FSTQueryData model for local storage in the query cache. */
- (FSTPBTarget *)encodedQueryData:(FSTQueryData *)queryData;

/** Decodes an FSTPBTarget proto from local storage into an FSTQueryData model. */
- (FSTQueryData *)decodedQueryData:(FSTPBTarget *)target;

/** Encodes an FSTSnapshotVersion model into a GPBTimestamp proto. */
- (GPBTimestamp *)encodedVersion:(FSTSnapshotVersion *)version;

/** Decodes a GPBTimestamp proto into a FSTSnapshotVersion model. */
- (FSTSnapshotVersion *)decodedVersion:(GPBTimestamp *)version;

@end

NS_ASSUME_NONNULL_END
