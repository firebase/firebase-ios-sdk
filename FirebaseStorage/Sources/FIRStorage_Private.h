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

@class FIRApp;
@class GTMSessionFetcherService;

NS_ASSUME_NONNULL_BEGIN

@interface FIRStorage ()

@property(strong, nonatomic, readwrite) FIRApp *app;

@property(strong, nonatomic, nullable) GTMSessionFetcherService *fetcherServiceForApp;

@property(nonatomic, readonly) dispatch_queue_t dispatchQueue;

@property(strong, nonatomic) NSString *storageBucket;

@property(strong, nonatomic) NSString *scheme;

@property(strong, nonatomic) NSString *host;

@property(strong, nonatomic) NSNumber *port;

/**
 * Maximum time between retry attempts for uploads.
 *
 * This is used by GTMSessionFetcher and translated from the user provided `maxUploadRetryTime`.
 */
@property(assign, nonatomic) NSTimeInterval maxUploadRetryInterval;

/**
 * Maximum time between retry attempts for downloads.
 *
 * This is used by GTMSessionFetcher and translated from the user provided `maxDownloadRetryTime`.
 */
@property(assign, nonatomic) NSTimeInterval maxDownloadRetryInterval;

/**
 * Maximum time between retry attempts for any operation that is not an upload or download.
 *
 * This is used by GTMSessionFetcher and translated from the user provided `maxOperationRetryTime`.
 */
@property(assign, nonatomic) NSTimeInterval maxOperationRetryInterval;

/**
 * Enables/disables GTMSessionFetcher HTTP logging
 * @param isLoggingEnabled Boolean passed through to enable/disable GTMSessionFetcher logging
 */
+ (void)setGTMSessionFetcherLoggingEnabled:(BOOL)isLoggingEnabled;

/** Configures the storage instance. Freezes the host setting. */
- (void)ensureConfigured;

@end

NS_ASSUME_NONNULL_END
