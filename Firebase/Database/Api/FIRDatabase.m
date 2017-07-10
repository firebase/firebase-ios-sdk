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
#import "FIRLogger.h"
#import "FIRDatabase.h"
#import "FIRDatabase_Private.h"
#import "FIRDatabaseQuery_Private.h"
#import "FRepoManager.h"
#import "FValidation.h"
#import "FIRDatabaseConfig_Private.h"
#import "FRepoInfo.h"
#import "FIRDatabaseConfig.h"
#import "FIRDatabaseReference_Private.h"

/**
 * This is a hack that defines all the methods we need from FIRApp/Options. At runtime we use reflection to get the
 * default FIRApp instance if we need it. Since protocols don't carry any runtime information and selectors
 * are invoked by name we can write code against this protocol as long as the method signatures don't change.
 *
 * TODO: Consider weak-linking the actual Firebase/Core framework or something.
 */

extern NSString *const kFIRDefaultAppName;

@protocol FIROptionsLike <NSObject>
@property(nonatomic, readonly, copy) NSString *databaseURL;
@end

@protocol FIRAppLike <NSObject>
@property(nonatomic, readonly) id<FIROptionsLike> options;
@property(nonatomic, copy, readonly) NSString *name;
@end

@interface FIRDatabase ()
@property (nonatomic, strong) FRepoInfo *repoInfo;
@property (nonatomic, strong) FIRDatabaseConfig *config;
@property (nonatomic, strong) FRepo *repo;
@end

@implementation FIRDatabase

// The STR and STR_EXPAND macro allow a numeric version passed to he compiler driver
// with a -D to be treated as a string instead of an invalid floating point value.
#define STR(x) STR_EXPAND(x)
#define STR_EXPAND(x) #x
static const char *FIREBASE_SEMVER = (const char *)STR(FIRDatabase_VERSION);

/**
 * A static NSMutableDictionary of FirebaseApp names to FirebaseDatabase instance. To ensure thread-
 * safety, it should only be accessed in databaseForApp, which is synchronized.
 *
 * TODO: This serves a duplicate purpose as RepoManager.  We should clean up.
 * TODO: We should maybe be conscious of leaks and make this a weak map or similar
 * but we have a lot of work to do to allow FirebaseDatabase/Repo etc. to be GC'd.
 */
+ (NSMutableDictionary *)instances {
    static dispatch_once_t pred = 0;
    static NSMutableDictionary *instances;
    dispatch_once(&pred, ^{
        instances = [NSMutableDictionary dictionary];
    });
    return instances;
}

+ (FIRDatabase *)database {
    id<FIRAppLike> app = [FIRDatabase getDefaultApp];
    if (app == nil) {
        [NSException raise:@"FIRAppNotConfigured" format:@"Failed to get default FIRDatabase instance. Must call FIRApp.configure() before using FIRDatabase."];
    }
    return [FIRDatabase databaseForApp:(FIRApp*)app];
}

+ (FIRDatabase *)databaseForApp:(id)app {
    if (app == nil) {
        [NSException raise:@"InvalidFIRApp" format:@"nil FIRApp instance passed to databaseForApp."];
    }
    NSMutableDictionary *instances = [self instances];
    @synchronized (instances) {
        id<FIRAppLike> appLike = (id<FIRAppLike>)app;
        FIRDatabase *database = instances[appLike.name];
        if (!database) {
            NSString *databaseUrl = appLike.options.databaseURL;
            if (databaseUrl == nil) {
                [NSException raise:@"MissingDatabaseURL" format:@"Failed to get FIRDatabase instance: FIRApp object has no "
                        "databaseURL in its FirebaseOptions object."];
            }

            FParsedUrl *parsedUrl = [FUtilities parseUrl:databaseUrl];
            if (![parsedUrl.path isEmpty]) {
                [NSException raise:@"InvalidDatabaseURL" format:@"Configured Database URL '%@' is invalid. It should "
                                                                        "point to the root of a Firebase Database but it includes a path: %@",
                                                                databaseUrl, [parsedUrl.path toString]];
            }

            id<FAuthTokenProvider> authTokenProvider = [FAuthTokenProvider authTokenProviderForApp:appLike];

            // If this is the default app, don't set the session persistence key so that we use our
            // default ("default") instead of the FIRApp default ("[DEFAULT]") so that we
            // preserve the default location used by the legacy Firebase SDK.
            NSString *sessionIdentifier = @"default";
            if (![appLike.name isEqualToString:kFIRDefaultAppName]) {
                sessionIdentifier = appLike.name;
            }

            FIRDatabaseConfig *config = [[FIRDatabaseConfig alloc] initWithSessionIdentifier:sessionIdentifier
                                                                           authTokenProvider:authTokenProvider];
            database = [[FIRDatabase alloc] initWithApp:appLike repoInfo:parsedUrl.repoInfo config:config];
            instances[appLike.name] = database;
        }

        return database;
    }
}

+ (NSString *) buildVersion {
    // TODO: Restore git hash when build moves back to git
    return [NSString stringWithFormat:@"%s_%s", FIREBASE_SEMVER, __DATE__];
}

+ (FIRDatabase *)createDatabaseForTests:(FRepoInfo *)repoInfo config:(FIRDatabaseConfig *)config {
    FIRDatabase *db = [[FIRDatabase alloc] initWithApp:nil repoInfo:repoInfo config:config];
    [db ensureRepo];
    return db;
}


+ (NSString *) sdkVersion {
    return [NSString stringWithUTF8String:FIREBASE_SEMVER];
}

+ (void) setLoggingEnabled:(BOOL)enabled {
    [FUtilities setLoggingEnabled:enabled];
    FFLog(@"I-RDB024001", @"BUILD Version: %@", [FIRDatabase buildVersion]);
}


- (id)initWithApp:(id <FIRAppLike>)appLike repoInfo:(FRepoInfo *)info config:(FIRDatabaseConfig *)config {
    self = [super init];
    if (self != nil) {
        self->_repoInfo = info;
        self->_config = config;
        self->_app = (FIRApp*) appLike;
    }
    return self;
}

- (FIRDatabaseReference *)reference {
    [self ensureRepo];

    return [[FIRDatabaseReference alloc] initWithRepo:self.repo path:[FPath empty]];
}

- (FIRDatabaseReference *)referenceWithPath:(NSString *)path {
    [self ensureRepo];

    [FValidation validateFrom:@"referenceWithPath" validRootPathString:path];
    FPath *childPath = [[FPath alloc] initWith:path];
    return [[FIRDatabaseReference alloc] initWithRepo:self.repo path:childPath];
}

- (FIRDatabaseReference *)referenceFromURL:(NSString *)databaseUrl {
    [self ensureRepo];

    if (databaseUrl == nil) {
        [NSException raise:@"InvalidDatabaseURL" format:@"Invalid nil url passed to referenceFromURL:"];
    }
    FParsedUrl *parsedUrl = [FUtilities parseUrl:databaseUrl];
    [FValidation validateFrom:@"referenceFromURL:" validURL:parsedUrl];
    if (![parsedUrl.repoInfo.host isEqualToString:_repoInfo.host]) {
        [NSException raise:@"InvalidDatabaseURL" format:@"Invalid URL (%@) passed to getReference(). URL was expected "
            "to match configured Database URL: %@", databaseUrl, [self reference].URL];
    }
    return [[FIRDatabaseReference alloc] initWithRepo:self.repo path:parsedUrl.path];
}


- (void)purgeOutstandingWrites {
    [self ensureRepo];

    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
        [self.repo purgeOutstandingWrites];
    });
}

- (void)goOnline {
    [self ensureRepo];

    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
        [self.repo resume];
    });
}


- (void)goOffline {
    [self ensureRepo];

    dispatch_async([FIRDatabaseQuery sharedQueue], ^{
        [self.repo interrupt];
    });
}

+ (id<FIRAppLike>) getDefaultApp {
    Class appClass = NSClassFromString(@"FIRApp");
    if (appClass == nil) {
        [NSException raise:@"FailedToFindFIRApp" format:@"Failed to find FIRApp class."];
        return nil;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        return [appClass performSelector:@selector(defaultApp)];
#pragma clang diagnostic pop
    }
}

- (void)setPersistenceEnabled:(BOOL)persistenceEnabled {
    [self assertUnfrozen:@"setPersistenceEnabled"];
    self->_config.persistenceEnabled = persistenceEnabled;
}

- (BOOL)persistenceEnabled {
    return self->_config.persistenceEnabled;
}

- (void)setPersistenceCacheSizeBytes:(NSUInteger)persistenceCacheSizeBytes {
    [self assertUnfrozen:@"setPersistenceCacheSizeBytes"];
    self->_config.persistenceCacheSizeBytes = persistenceCacheSizeBytes;
}

- (NSUInteger)persistenceCacheSizeBytes {
    return self->_config.persistenceCacheSizeBytes;
}

- (void)setCallbackQueue:(dispatch_queue_t)callbackQueue {
    [self assertUnfrozen:@"setCallbackQueue"];
    self->_config.callbackQueue = callbackQueue;
}

- (dispatch_queue_t)callbackQueue {
    return self->_config.callbackQueue;
}

- (void) assertUnfrozen:(NSString*)methodName {
    if (self.repo != nil) {
        [NSException raise:@"FIRDatabaseAlreadyInUse" format:@"Calls to %@ must be made before any other usage of "
                "FIRDatabase instance.", methodName];
    }
}

- (void) ensureRepo {
    if (self.repo == nil) {
        self.repo = [FRepoManager createRepo:self.repoInfo config:self.config database:self];
    }
}

@end
