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

@protocol FAuthTokenProvider;

NS_ASSUME_NONNULL_BEGIN

/**
 * TODO: Merge FIRDatabaseConfig into FIRDatabase.
 */
@interface FIRDatabaseConfig : NSObject

- (id)initWithSessionIdentifier:(NSString *)identifier
              authTokenProvider:(id<FAuthTokenProvider>)authTokenProvider;

/**
 * By default the Firebase Database client will keep data in memory while your
 * application is running, but not when it is restarted. By setting this value
 * to YES, the data will be persisted to on-device (disk) storage and will thus
 * be available again when the app is restarted (even when there is no network
 * connectivity at that time). Note that this property must be set before
 * creating your first FIRDatabaseReference and only needs to be called once per
 * application.
 *
 * If your app uses Firebase Authentication, the client will automatically
 * persist the user's authentication token across restarts, even without
 * persistence enabled. But if the auth token expired while offline and you've
 * enabled persistence, the client will pause write operations until you
 * successfully re-authenticate (or explicitly unauthenticate) to prevent your
 * writes from being sent unauthenticated and failing due to security rules.
 */
@property(nonatomic) BOOL persistenceEnabled;

/**
 * By default the Firebase Database client will use up to 10MB of disk space to
 * cache data. If the cache grows beyond this size, the client will start
 * removing data that hasn't been recently used. If you find that your
 * application caches too little or too much data, call this method to change
 * the cache size. This property must be set before creating your first
 * FIRDatabaseReference and only needs to be called once per application.
 *
 * Note that the specified cache size is only an approximation and the size on
 * disk may temporarily exceed it at times.
 */
@property(nonatomic) NSUInteger persistenceCacheSizeBytes;

/**
 * Sets the dispatch queue on which all events are raised. The default queue is
 * the main queue.
 */
@property(nonatomic, strong) dispatch_queue_t callbackQueue;

@end

NS_ASSUME_NONNULL_END
