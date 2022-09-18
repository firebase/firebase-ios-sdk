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

@class FIRIMPLStorageDownloadTask;
@class FIRIMPLStorageMetadata;
@class FIRIMPLStorageTaskSnapshot;
@class FIRIMPLStorageUploadTask;

NS_ASSUME_NONNULL_BEGIN

// TODO: The typedefs are not portable to Swift as typealias's to make available
// back to Objective-C. See https://stackoverflow.com/a/48069912/556617
/**
 * NSString typedef representing a task listener handle.
 */
typedef NSString *FIRStorageHandle;

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
typedef void (^FIRStorageVoidMetadata)(FIRIMPLStorageMetadata *_Nullable metadata);

/**
 * Block typedef typically used when retrieving metadata with the possibility of an error.
 * @param metadata The metadata returned by the operation, if metadata exists.
 * @param error The error describing failure, if one occurred.
 */
typedef void (^FIRStorageVoidMetadataError)(FIRIMPLStorageMetadata *_Nullable metadata,
                                            NSError *_Nullable error);

/**
 * Block typedef typically used to asynchronously return a storage task snapshot.
 * @param snapshot The returned task snapshot.
 */
typedef void (^FIRStorageVoidSnapshot)(FIRIMPLStorageTaskSnapshot *snapshot);

/**
 * Block typedef typically used when retrieving a download URL.
 * @param URL The download URL associated with the operation.
 * @param error The error describing failure, if one occurred.
 */
typedef void (^FIRStorageVoidURLError)(NSURL *_Nullable URL, NSError *_Nullable error);

/**
 * Enum representing the upload and download task status.
 */
typedef NS_ENUM(NSInteger, FIRIMPLStorageTaskStatus) {
  /**
   * Unknown task status.
   */
  FIRIMPLStorageTaskStatusUnknown,

  /**
   * Task is being resumed.
   */
  FIRIMPLStorageTaskStatusResume,

  /**
   * Task reported a progress event.
   */
  FIRIMPLStorageTaskStatusProgress,

  /**
   * Task is paused.
   */
  FIRIMPLStorageTaskStatusPause,

  /**
   * Task has completed successfully.
   */
  FIRIMPLStorageTaskStatusSuccess,

  /**
   * Task has failed and is unrecoverable.
   */
  FIRIMPLStorageTaskStatusFailure
};

/**
 * Enum representing the errors raised by Firebase Storage.
 */
typedef NS_ENUM(NSInteger, FIRIMPLStorageErrorCode) {
  /** An unknown error occurred. */
  FIRIMPLStorageErrorCodeUnknown = -13000,

  /** No object exists at the desired reference. */
  FIRIMPLStorageErrorCodeObjectNotFound = -13010,

  /** No bucket is configured for Firebase Storage. */
  FIRIMPLStorageErrorCodeBucketNotFound = -13011,

  /** No project is configured for Firebase Storage. */
  FIRIMPLStorageErrorCodeProjectNotFound = -13012,

  /**
   * Quota on your Firebase Storage bucket has been exceeded.
   * If you're on the free tier, upgrade to a paid plan.
   * If you're on a paid plan, reach out to Firebase support.
   */
  FIRIMPLStorageErrorCodeQuotaExceeded = -13013,

  /** User is unauthenticated. Authenticate and try again. */
  FIRIMPLStorageErrorCodeUnauthenticated = -13020,

  /**
   * User is not authorized to perform the desired action.
   * Check your rules to ensure they are correct.
   */
  FIRIMPLStorageErrorCodeUnauthorized = -13021,

  /**
   * The maximum time limit on an operation (upload, download, delete, etc.) has been exceeded.
   * Try uploading again.
   */
  FIRIMPLStorageErrorCodeRetryLimitExceeded = -13030,

  /**
   * File on the client does not match the checksum of the file received by the server.
   * Try uploading again.
   */
  FIRIMPLStorageErrorCodeNonMatchingChecksum = -13031,

  /**
   * Size of the downloaded file exceeds the amount of memory allocated for the download.
   * Increase memory cap and try downloading again.
   */
  FIRIMPLStorageErrorCodeDownloadSizeExceeded = -13032,

  /** User cancelled the operation. */
  FIRIMPLStorageErrorCodeCancelled = -13040,

  /** An invalid argument was provided. */
  FIRIMPLStorageErrorCodeInvalidArgument = -13050
};

NS_ASSUME_NONNULL_END
