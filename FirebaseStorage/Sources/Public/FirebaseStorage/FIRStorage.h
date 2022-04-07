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

#import "FIRStorageConstants.h"

@class FIRApp;
@class FIRIMPLStorageReference;
@protocol FIRAppCheckInterop;
@protocol FIRAuthInterop;

NS_ASSUME_NONNULL_BEGIN

/**
 * FirebaseStorage is a service that supports uploading and downloading binary objects,
 * such as images, videos, and other files to Google Cloud Storage.
 *
 * If you call [FIRStorage storage], the instance will initialize with the default FIRApp,
 * [FIRApp defaultApp], and the storage location will come from the provided
 * GoogleService-Info.plist.
 *
 * If you call [FIRStorage storageForApp:] and provide a custom instance of FIRApp,
 * the storage location will be specified via the FIROptions#storageBucket property.
 */
@interface FIRIMPLStorage : NSObject

/**
 * Return the Storage bucket for the FIRApp @a app.
 * @param app The custom FIRApp used for initialization.
 * @return the FIRStorage instance, initialized with the custom FIRApp.
 */
+ (NSString *)bucketForApp:(FIRApp *)app;

/**
 * Return the Storage URL string for the custom FIRApp @a app and a custom storage
 * bucket @a url.
 * @param app The custom FIRApp used for initialization.
 * @param url The gs:// url to your Firebase Storage Bucket.
 * @return the FIRStorage instance, initialized with the custom FIRApp.
 */
+ (NSString *)bucketForApp:(FIRApp *)app URL:(NSString *)url;

- (instancetype)initWithApp:(FIRApp *)app
                     bucket:(NSString *)bucket
                       auth:(nullable id<FIRAuthInterop>)auth
                   appCheck:(nullable id<FIRAppCheckInterop>)appCheck;

/**
 * The Firebase App associated with this Firebase Storage instance.
 */
@property(strong, nonatomic, readonly) FIRApp *app;

/**
 * Maximum time in seconds to retry an upload if a failure occurs.
 * Defaults to 10 minutes (600 seconds).
 */
@property NSTimeInterval maxUploadRetryTime;

/**
 * Maximum time in seconds to retry a download if a failure occurs.
 * Defaults to 10 minutes (600 seconds).
 */
@property NSTimeInterval maxDownloadRetryTime;

/**
 * Maximum time in seconds to retry operations other than upload and download if a failure occurs.
 * Defaults to 2 minutes (120 seconds).
 */
@property NSTimeInterval maxOperationRetryTime;

/**
 * Queue that all developer callbacks are fired on. Defaults to the main queue.
 */
@property(strong, nonatomic) dispatch_queue_t callbackQueue;

/**
 * Creates a FIRIMPLStorageReference initialized at the root Firebase Storage location.
 * @return An instance of FIRIMPLStorageReference initialized at the root.
 */
- (FIRIMPLStorageReference *)reference;

/**
 * Creates a FIRIMPLStorageReference given a gs:// or https:// URL pointing to a Firebase Storage
 * location. For example, you can pass in an https:// download URL retrieved from
 * [FIRIMPLStorageReference downloadURLWithCompletion] or the gs:// URI from
 * [FIRIMPLStorageReference description].
 * @param string A gs:// or https:// URL to initialize the reference with.
 * @return An instance of FIRIMPLStorageReference at the given child path.
 * @throws Throws an exception if passed in URL is not associated with the FIRApp used to initialize
 * this FIRStorage.
 */
- (FIRIMPLStorageReference *)referenceForURL:(NSString *)string;

/**
 * Creates a FIRIMPLStorageReference initialized at a child Firebase Storage location.
 * @param string A relative path from the root to initialize the reference with,
 * for instance @"path/to/object".
 * @return An instance of FIRIMPLStorageReference at the given child path.
 */
- (FIRIMPLStorageReference *)referenceWithPath:(NSString *)string;

/**
 * Configures the Storage SDK to use an emulated backend instead of the default remote backend.
 */
- (void)useEmulatorWithHost:(NSString *)host port:(NSInteger)port;

@end

NS_ASSUME_NONNULL_END
