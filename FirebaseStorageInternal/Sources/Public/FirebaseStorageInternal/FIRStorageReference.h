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

#import "FIRStorage.h"
#import "FIRStorageConstants.h"
#import "FIRStorageListResult.h"
#import "FIRStorageMetadata.h"
#import "FIRStoragePath.h"
#import "FIRStorageTask.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * FIRIMPLStorageReference represents a reference to a Google Cloud Storage object. Developers can
 * upload and download objects, as well as get/set object metadata, and delete an object at the
 * path.
 * @see https://cloud.google.com/storage/
 */
@interface FIRIMPLStorageReference : NSObject

/**
 * The FIRStorage service object which created this reference.
 */
@property(nonatomic, readonly) FIRIMPLStorage *storage;

/**
 * The name of the Google Cloud Storage bucket associated with this reference,
 * in gs://bucket/path/to/object.txt, the bucket would be: 'bucket'
 */
@property(nonatomic, readonly) NSString *bucket;

/**
 * The full path to this object, not including the Google Cloud Storage bucket.
 * In gs://bucket/path/to/object.txt, the full path would be: 'path/to/object.txt'
 */
@property(nonatomic, readonly) NSString *fullPath;

/**
 * The short name of the object associated with this reference,
 * in gs://bucket/path/to/object.txt, the name of the object would be: 'object.txt'
 */
@property(nonatomic, readonly) NSString *name;

/**
 * The current path which points to an object in the Google Cloud Storage bucket.
 */
@property(strong, nonatomic) FIRStoragePath *path;

#pragma mark - Path Operations

/**
 * Creates a new FIRIMPLStorageReference pointing to the root object.
 * @return A new FIRIMPLStorageReference pointing to the root object.
 */
- (FIRIMPLStorageReference *)root;

/**
 * Creates a new FIRIMPLStorageReference pointing to the parent of the current reference
 * or nil if this instance references the root location.
 * For example:
 *   path = foo/bar/baz   parent = foo/bar
 *   path = foo           parent = (root)
 *   path = (root)        parent = nil
 * @return A new FIRIMPLStorageReference pointing to the parent of the current reference.
 */
- (nullable FIRIMPLStorageReference *)parent;

/**
 * Creates a new FIRIMPLStorageReference pointing to a child object of the current reference.
 *   path = foo      child = bar    newPath = foo/bar
 *   path = foo/bar  child = baz    newPath = foo/bar/baz
 * All leading and trailing slashes will be removed, and consecutive slashes will be
 * compressed to single slashes. For example:
 *   child = /foo/bar     newPath = foo/bar
 *   child = foo/bar/     newPath = foo/bar
 *   child = foo///bar    newPath = foo/bar
 * @param path Path to append to the current path.
 * @return A new FIRIMPLStorageReference pointing to a child location of the current reference.
 */
- (FIRIMPLStorageReference *)child:(NSString *)path;

/**
 * Asynchronously retrieves a long lived download URL with a revokable token.
 * This can be used to share the file with others, but can be revoked by a developer
 * in the Firebase Console.
 * @param completion A completion block that either returns the URL on success,
 * or an error on failure.
 */
- (void)downloadURLWithCompletion:(void (^)(NSURL *_Nullable URL,
                                            NSError *_Nullable error))completion;

#pragma mark - List Support

/**
 * List all items (files) and prefixes (folders) under this StorageReference.
 *
 * This is a helper method for calling list() repeatedly until there are no more results.
 * Consistency of the result is not guaranteed if objects are inserted or removed while this
 * operation is executing. All results are buffered in memory.
 *
 * `listAll(completion:)` is only available for projects using Firebase Rules Version 2.
 *
 * @param completion A completion handler that will be invoked with all items and prefixes under
 * the current StorageReference.
 */
- (void)listAllWithCompletion:(void (^)(FIRIMPLStorageListResult *result,
                                        NSError *_Nullable error))completion;

/**
 * List up to `maxResults` items (files) and prefixes (folders) under this StorageReference.
 *
 * "/" is treated as a path delimiter. Firebase Storage does not support unsupported object
 * paths that end with "/" or contain two consecutive "/"s. All invalid objects in GCS will be
 * filtered.
 *
 * `list(maxResults:completion:)` is only available for projects using Firebase Rules Version 2.
 *
 * @param maxResults The maximum number of results to return in a single page. Must be greater
 * than 0 and at most 1000.
 * @param completion A completion handler that will be invoked with up to maxResults items and
 * prefixes under the current StorageReference.
 */
- (void)listWithMaxResults:(int64_t)maxResults
                completion:(void (^)(FIRIMPLStorageListResult *result,
                                     NSError *_Nullable error))completion;

/**
 * Resumes a previous call to list(maxResults:completion:)`, starting after a pagination token.
 * Returns the next set of items (files) and prefixes (folders) under this StorageReference.
 *
 * "/" is treated as a path delimiter. Firebase Storage does not support unsupported object
 * paths that end with "/" or contain two consecutive "/"s. All invalid objects in GCS will be
 * filtered.
 *
 * `list(maxResults:pageToken:completion:)`is only available for projects using Firebase Rules
 * Version 2.
 *
 * @param maxResults The maximum number of results to return in a single page. Must be greater
 * than 0 and at most 1000.
 * @param pageToken A page token from a previous call to list.
 * @param completion A completion handler that will be invoked with the next items and prefixes
 * under the current StorageReference.
 */
- (void)listWithMaxResults:(int64_t)maxResults
                 pageToken:(NSString *)pageToken
                completion:(void (^)(FIRIMPLStorageListResult *result,
                                     NSError *_Nullable error))completion;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
