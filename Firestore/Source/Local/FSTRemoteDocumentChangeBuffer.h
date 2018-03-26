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

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

NS_ASSUME_NONNULL_BEGIN

@protocol FSTRemoteDocumentCache;
@class FSTMaybeDocument;

/**
 * An in-memory buffer of entries to be written to an FSTRemoteDocumentCache. It can be used to
 * batch up a set of changes to be written to the cache, but additionally supports reading entries
 * back with the `entryForKey:` method, falling back to the underlying FSTRemoteDocumentCache if
 * no entry is buffered. In the absence of LevelDB transactions (that would allow reading back
 * uncommitted writes), this greatly simplifies the implementation of complex operations that
 * may want to freely read/write entries to the FSTRemoteDocumentCache while still ensuring that
 * the final writing of the buffered entries is atomic.
 *
 * For doing blind writes that don't depend on the current state of the FSTRemoteDocumentCache
 * or for plain reads, you can/should still just use the FSTRemoteDocumentCache directly.
 */
@interface FSTRemoteDocumentChangeBuffer : NSObject

+ (instancetype)changeBufferWithCache:(id<FSTRemoteDocumentCache>)cache;

- (instancetype)init __attribute__((unavailable("Use a static constructor instead")));

/** Buffers an `FSTRemoteDocumentCache addEntry:group:` call. */
- (void)addEntry:(FSTMaybeDocument *)maybeDocument;

// NOTE: removeEntryForKey: is not presently necessary and so is omitted.

/**
 * Looks up an entry in the cache. The buffered changes will first be checked, and if no
 * buffered change applies, this will forward to `FSTRemoteDocumentCache entryForKey:`.
 *
 * @param documentKey The key of the entry to look up.
 * @return The cached FSTDocument or FSTDeletedDocument entry, or nil if we have nothing cached.
 */
- (nullable FSTMaybeDocument *)entryForKey:
    (const firebase::firestore::model::DocumentKey &)documentKey;

/**
 * Applies buffered changes to the underlying FSTRemoteDocumentCache
 */
- (void)apply;

@end

NS_ASSUME_NONNULL_END
