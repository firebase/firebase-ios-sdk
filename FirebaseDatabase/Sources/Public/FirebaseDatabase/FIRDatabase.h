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

#import "FIRDatabaseReference.h"
#import <Foundation/Foundation.h>

@class FIRApp;

NS_ASSUME_NONNULL_BEGIN

/**
 * The entry point for accessing a Firebase Database.  You can get an instance
 * by calling `Database.database()`. To access a location in the database and
 * read or write data, use `FIRDatabase.reference()`.
 */
NS_SWIFT_NAME(Database)
@interface FIRDatabase : NSObject

/**
 * The NSObject initializer that has been marked as unavailable. Use the
 * `database` class method instead.
 */
- (instancetype)init
    __attribute__((unavailable("use the database method instead")));

/**
 * Gets the instance of `Database` for the default `FirebaseApp`.
 *
 * @return A `Database` instance.
 */
+ (FIRDatabase *)database NS_SWIFT_NAME(database());

/**
 * Gets a `Database` instance for the specified URL.
 *
 * @param url The URL to the Firebase Database instance you want to access.
 * @return A `Database` instance.
 */
+ (FIRDatabase *)databaseWithURL:(NSString *)url NS_SWIFT_NAME(database(url:));

/**
 * Gets a `Database` instance for the specified URL, using the specified
 * `FirebaseApp`.
 *
 * @param app The app to get a `Database` for.
 * @param url The URL to the Firebase Database instance you want to access.
 * @return A `Database` instance.
 */
// clang-format off
+ (FIRDatabase *)databaseForApp:(FIRApp *)app
                            URL:(NSString *)url NS_SWIFT_NAME(database(app:url:));
// clang-format on

/**
 * Gets an instance of `Database` for a specific `FirebaseApp`.
 *
 * @param app The app to get a `Database` for.
 * @return A `Database` instance.
 */
+ (FIRDatabase *)databaseForApp:(FIRApp *)app NS_SWIFT_NAME(database(app:));

/** The app instance to which this `Database` belongs. */
@property(weak, readonly, nonatomic) FIRApp *app;

/**
 * Gets a `DatabaseReference` for the root of your Firebase Database.
 */
- (FIRDatabaseReference *)reference;

/**
 * Gets a `DatabaseReference` for the provided path.
 *
 * @param path Path to a location in your Firebase Database.
 * @return A `DatabaseReference` pointing to the specified path.
 */
- (FIRDatabaseReference *)referenceWithPath:(NSString *)path;

/**
 * Gets a `DatabaseReference` for the provided URL.  The URL must be a URL to a
 * path within this Firebase Database.  To create a `DatabaseReference` to a
 * different database, create a `FirebaseApp` with an `Options` object
 * configured with the appropriate database URL.
 *
 * @param databaseUrl A URL to a path within your database.
 * @return A `DatabaseReference` for the provided URL.
 */
- (FIRDatabaseReference *)referenceFromURL:(NSString *)databaseUrl;

/**
 * The Firebase Database client automatically queues writes and sends them to
 * the server at the earliest opportunity, depending on network connectivity. In
 * some cases (e.g. offline usage) there may be a large number of writes waiting
 * to be sent. Calling this method will purge all outstanding writes so they are
 * abandoned.
 *
 * All writes will be purged, including transactions and onDisconnect writes.
 * The writes will be rolled back locally, perhaps triggering events for
 * affected event listeners, and the client will not (re-)send them to the
 * Firebase Database backend.
 */
- (void)purgeOutstandingWrites;

/**
 * Shuts down the connection to the Firebase Database backend until `goOnline()`
 * is called.
 */
- (void)goOffline;

/**
 * Resumes the connection to the Firebase Database backend after a previous
 * goOffline() call.
 */
- (void)goOnline;

/**
 * The Firebase Database client will cache synchronized data and keep track of
 * all writes you've initiated while your application is running. It seamlessly
 * handles intermittent network connections and re-sends write operations when
 * the network connection is restored.
 *
 * However by default your write operations and cached data are only stored
 * in-memory and will be lost when your app restarts.  By setting this value to
 * `true`, the data will be persisted to on-device (disk) storage and will thus
 * be available again when the app is restarted (even when there is no network
 * connectivity at that time). Note that this property must be set before
 * creating your first `DatabaseReference` and only needs to be called once per
 * application.
 *
 */
@property(nonatomic) BOOL persistenceEnabled NS_SWIFT_NAME(isPersistenceEnabled)
    ;

/**
 * By default the Firebase Database client will use up to 10MB of disk space to
 * cache data. If the cache grows beyond this size, the client will start
 * removing data that hasn't been recently used. If you find that your
 * application caches too little or too much data, call this method to change
 * the cache size. This property must be set before creating your first
 * `DatabaseReference` and only needs to be called once per application.
 *
 * Note that the specified cache size is only an approximation and the size on
 * disk may temporarily exceed it at times. Cache sizes smaller than 1 MB or
 * greater than 100 MB are not supported.
 */
@property(nonatomic) NSUInteger persistenceCacheSizeBytes;

/**
 * Sets the dispatch queue on which all events are raised. The default queue is
 * the main queue.
 *
 * Note that this must be set before creating your first Database reference.
 */
@property(nonatomic, strong) dispatch_queue_t callbackQueue;

/**
 * Enables verbose diagnostic logging.
 *
 * @param enabled true to enable logging, false to disable.
 */
+ (void)setLoggingEnabled:(BOOL)enabled;

/** Retrieve the Firebase Database SDK version. */
+ (NSString *)sdkVersion;

/**
 * Configures the database to use an emulated backend instead of the default
 * remote backend.
 */
- (void)useEmulatorWithHost:(NSString *)host port:(NSInteger)port;

@end

NS_ASSUME_NONNULL_END
