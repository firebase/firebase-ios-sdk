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

#include <set>

#import "Firestore/Source/Core/FSTTypes.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

@class FSTDocumentReference;
@protocol FSTGarbageCollector;

NS_ASSUME_NONNULL_BEGIN

/**
 * A pseudo-collection that maintains references to documents. FSTGarbageSource collections
 * notify the FSTGarbageCollector when references to documents change through the
 * -addPotentialGarbageKey: message.
 */
@protocol FSTGarbageSource

/**
 * The garbage collector to which this collection should send -addPotentialGarbageKey: messages.
 */
@property(nonatomic, weak, readwrite, nullable) id<FSTGarbageCollector> garbageCollector;

/**
 * Checks to see if there are any references to a document with the given key. This can be used by
 * garbage collectors to double-check if a key exists in this collection when it was released
 * elsewhere.
 */
- (BOOL)containsKey:(const firebase::firestore::model::DocumentKey&)key;

@end

/**
 * Tracks different kinds of references to a document, for all the different ways the client
 * needs to retain a document.
 *
 * Usually the local store this means tracking of three different types of references to a
 * document:
 * 1. RemoteTarget reference identified by a target ID.
 * 2. LocalView reference identified also by a target ID.
 * 3. Local mutation reference identified by a batch ID.
 *
 * The idea is that we want to keep a document around at least as long as any remote target or
 * local (latency compensated) view is referencing it, or there's an outstanding local mutation to
 * that document.
 */
@protocol FSTGarbageCollector

/**
 * A property that describes whether or not the collector wants to eagerly collect keys.
 *
 * TODO(b/33384523) Delegate deleting released queries to the GC.
 * This flag is a temporary workaround for dealing with a persistent query cache. The collector
 * really should have an API for releasing queries that does the right thing for its policy.
 */
@property(nonatomic, assign, readonly, getter=isEager) BOOL eager;

/** Adds a garbage source to the collector. */
- (void)addGarbageSource:(id<FSTGarbageSource>)garbageSource;

/** Removes a garbage source from the collector. */
- (void)removeGarbageSource:(id<FSTGarbageSource>)garbageSource;

/**
 * Notifies the garbage collector that a document with the given key may have become garbage.
 *
 * This is useful in both when a document has definitely been released (for example when removed
 * from a garbage source) but also when a document has been updated. Documents should be marked in
 * this way because the client accepts updates for documents even after the document no longer
 * matches any active targets. This behavior allows the client to avoid re-showing an old document
 * in the next latency-compensated view.
 */
- (void)addPotentialGarbageKey:(const firebase::firestore::model::DocumentKey&)key;

/** Returns the contents of the garbage bin and clears it. */
- (std::set<firebase::firestore::model::DocumentKey>)collectGarbage;

@end

NS_ASSUME_NONNULL_END
