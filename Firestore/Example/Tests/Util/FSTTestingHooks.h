/*
 * Copyright 2023 Google LLC
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

// NOTE: For Swift compatibility, please keep this header Objective-C only.
//       Swift cannot interact with any C++ definitions.
#import <Foundation/Foundation.h>

@class FIRDocumentReference;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTTestingHooksBloomFilter

/**
 * Information about the bloom filter provided by Watch in the ExistenceFilter message's
 * `unchanged_names` field.
 */
@interface FSTTestingHooksBloomFilter : NSObject

- (instancetype)init __attribute__((unavailable("instances cannot be created directly")));

/**
 * Whether a full requery was averted by using the bloom filter. If false, then something happened,
 * such as a false positive, to prevent using the bloom filter to avoid a full requery.
 */
@property(nonatomic, readonly) BOOL applied;

/** The number of hash functions used in the bloom filter. */
@property(nonatomic, readonly) int hashCount;

/** The number of bytes in the bloom filter's bitmask. */
@property(nonatomic, readonly) int bitmapLength;

/** The number of bits of padding in the last byte of the bloom filter. */
@property(nonatomic, readonly) int padding;

/** Returns whether the bloom filter contains the given document. */
- (BOOL)mightContain:(FIRDocumentReference*)documentRef;

@end  // @interface FSTTestingHooksBloomFilter

#pragma mark - FSTTestingHooksExistenceFilterMismatchInfo

/**
 * Information about an existence filter mismatch.
 */
@interface FSTTestingHooksExistenceFilterMismatchInfo : NSObject

- (instancetype)init __attribute__((unavailable("instances cannot be created directly")));

/** The number of documents that matched the query in the local cache. */
@property(nonatomic, readonly) int localCacheCount;

/**
 * The number of documents that matched the query on the server, as specified in the
 * `ExistenceFilter` message's `count` field.
 */
@property(nonatomic, readonly) int existenceFilterCount;

/**
 * Information about the bloom filter provided by Watch in the ExistenceFilter message's
 * `unchanged_names` field. If nil, then that means that Watch did _not_ provide a bloom filter.
 */
@property(nonatomic, readonly, nullable) FSTTestingHooksBloomFilter* bloomFilter;

@end

#pragma mark - FSTTestingHooks

/**
 * Manages "testing hooks", hooks into the internals of the SDK to verify internal state and events
 * during integration tests.
 */
@interface FSTTestingHooks : NSObject

- (instancetype)init __attribute__((unavailable("instances cannot be created")));

/**
 * Captures all existence filter mismatches in the Watch 'Listen' stream that occur during the
 * execution of the given block.
 *
 * @param block The block to execute; during the execution of this block all existence filter
 * mismatches will be captured.
 *
 * @return the captured existence filter mismatches.
 */
+ (NSArray<FSTTestingHooksExistenceFilterMismatchInfo*>*)
    captureExistenceFilterMismatchesDuringBlock:(void (^)())block;

@end

NS_ASSUME_NONNULL_END
