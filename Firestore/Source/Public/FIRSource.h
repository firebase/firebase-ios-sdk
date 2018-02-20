/*
 * Copyright 2018 Google
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

/**
 * An enum that configures the behavior of `DocumentReference.getDocument()`
 * and `CollectionReference.getDocuments()`.  By providing a source enum the
 * `getDocument[s]` methods can be configured to fetch results only from the
 * server, only from the local cache, or attempt the server and fall back to
 * the cache (which is the default).
 *
 * Setting the source to FIRSourceDefault, if online, causes Firestore to try
 * to give a consistent (server-retrieved) snapshot, or else revert to the
 * cache to provide a value.
 *
 * FIRSourceServer causes Firestore to avoid the cache (generating an error if
 * a value cannot be retrieved from the server). The cache will be updated if
 * the RPC succeeds. Latency compensation still occurs (implying that if the
 * cache is more up to date, then it's values will be merged into the results).
 *
 * FIRSourceCache causes Firestore to immediately return a value from the
 * cache, ignoring the server completely (implying that the returned value may
 * be stale with respect to the value on the server.) For a single document,
 * the get will fail if the document doesn't exist.
 */
typedef NS_ENUM(NSUInteger, FIRSource) {
  FIRSourceDefault,
  FIRSourceServer,
  FIRSourceCache
} NS_SWIFT_NAME(Source);
