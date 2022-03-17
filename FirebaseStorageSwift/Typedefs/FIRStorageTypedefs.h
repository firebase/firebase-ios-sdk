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

@class FIRStorageDownloadTask;
@class FIRStorageMetadata;
@class FIRStorageTaskSnapshot;
@class FIRStorageUploadTask;

NS_ASSUME_NONNULL_BEGIN

/**
 * NSString typedef representing a task listener handle.
 */
typedef NSString *FIRStorageHandle NS_SWIFT_NAME(StorageHandle);

/**
 * Block typedef typically used when downloading data.
 * @param data The data returned by the download, or nil if no data available or download failed.
 * @param error The error describing failure, if one occurred.
 */
typedef void (^FIRStorageVoidDataError)(NSData *_Nullable data, NSError *_Nullable error);

/**
 * Block typedef typically used when performing "binary" async operations such as delete,
 * where the operation either succeeds without an error or fails with an error.
 * @param error The error describing failure, if one occurred.
 */
typedef void (^FIRStorageVoidError)(NSError *_Nullable error);

/**
 * Block typedef typically used when retrieving metadata.
 * @param metadata The metadata returned by the operation, if metadata exists.
 */
typedef void (^FIRStorageVoidMetadata)(FIRStorageMetadata *_Nullable metadata);

/**
 * Block typedef typically used when retrieving metadata with the possibility of an error.
 * @param metadata The metadata returned by the operation, if metadata exists.
 * @param error The error describing failure, if one occurred.
 */
typedef void (^FIRStorageVoidMetadataError)(FIRStorageMetadata *_Nullable metadata,
                                            NSError *_Nullable error);

/**
 * Block typedef typically used to asynchronously return a storage task snapshot.
 * @param snapshot The returned task snapshot.
 */
typedef void (^FIRStorageVoidSnapshot)(FIRStorageTaskSnapshot *snapshot);

/**
 * Block typedef typically used when retrieving a download URL.
 * @param URL The download URL associated with the operation.
 * @param error The error describing failure, if one occurred.
 */
typedef void (^FIRStorageVoidURLError)(NSURL *_Nullable URL, NSError *_Nullable error);

NS_ASSUME_NONNULL_END
