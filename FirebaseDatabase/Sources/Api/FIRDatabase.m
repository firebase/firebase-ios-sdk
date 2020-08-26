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

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "Interop/Auth/Public/FIRAuthInterop.h"

#import "FirebaseDatabase/Sources/Api/FIRDatabaseComponent.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseReference_Private.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabase_Private.h"
#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/FIRDatabaseConfig_Private.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDatabase.h"
#import "FirebaseDatabase/Sources/Utilities/FValidation.h"

@implementation FIRDatabase

// The STR and STR_EXPAND macro allow a numeric version passed to he compiler
// driver with a -D to be treated as a string instead of an invalid floating
// point value.
#define STR(x) STR_EXPAND(x)
#define STR_EXPAND(x) #x
static const char *FIREBASE_SEMVER = (const char *)STR(FIRDatabase_VERSION);

+ (FIRDatabase *)database {
    if (![FIRApp isDefaultAppConfigured]) {
        [NSException raise:@"FIRAppNotConfigured"
                    format:@"Failed to get default Firebase Database instance. "
                           @"Must call `[FIRApp "
                           @"configure]` (`FirebaseApp.configure()` in Swift) "
                           @"before using "
                           @"Firebase Database."];
    }
    return [FIRDatabase databaseForApp:[FIRApp defaultApp]];
}

+ (FIRDatabase *)databaseWithURL:(NSString *)url {
    FIRApp *app = [FIRApp defaultApp];
    if (app == nil) {
        [NSException
             raise:@"FIRAppNotConfigured"
            format:
                @"Failed to get default Firebase Database instance. "
                @"Must call `[FIRApp configure]` (`FirebaseApp.configure()` in "
                @"Swift) before using Firebase Database."];
    }
    return [FIRDatabase databaseForApp:app URL:url];
}

+ (FIRDatabase *)databaseForApp:(FIRApp *)app {
    if (app == nil) {
        [NSException raise:@"InvalidFIRApp"
                    format:@"nil FIRApp instance passed to databaseForApp."];
    }
    NSString *url = app.options.databaseURL;
    if (!url) {
        if (!app.options.projectID) {
            [NSException
                 raise:@"MissingProjectId"
                format:@"Can't determine Firebase Database URL. Be sure to "
                       @"include a Project ID when calling "
                       @"`FirebaseApp.configure()`."];
        }
        FFLog(@"I-RDB024002", @"Using default host for project %@",
              app.options.projectID);
        url = [NSString
            stringWithFormat:@"https://%@-default-rtdb.firebaseio.com",
                             app.options.projectID];
    }
    return [FIRDatabase databaseForApp:app URL:url];
}

+ (FIRDatabase *)databaseForApp:(FIRApp *)app URL:(NSString *)url {
    if (app == nil) {
        [NSException raise:@"InvalidFIRApp"
                    format:@"nil FIRApp instance passed to databaseForApp."];
    }
    if (url == nil) {
        [NSException raise:@"MissingDatabaseURL"
                    format:@"Failed to get FirebaseDatabase instance: "
                           @"Specify DatabaseURL within FIRApp or from your "
                           @"databaseForApp:URL: call."];
    }
    id<FIRDatabaseProvider> provider =
        FIR_COMPONENT(FIRDatabaseProvider, app.container);
    return [provider databaseForApp:app URL:url];
}

+ (NSString *)buildVersion {
    // TODO: Restore git hash when build moves back to git
    return [NSString stringWithFormat:@"%s_%s", FIREBASE_SEMVER, __DATE__];
}

+ (FIRDatabase *)createDatabaseForTests:(FRepoInfo *)repoInfo
                                 config:(FIRDatabaseConfig *)config {
    FIRDatabase *db = [[FIRDatabase alloc] initWithApp:nil
                                              repoInfo:repoInfo
                                                config:config];
    [db ensureRepo];
    return db;
}

+ (NSString *)sdkVersion {
    return [NSString stringWithUTF8String:FIREBASE_SEMVER];
}

+ (void)setLoggingEnabled:(BOOL)enabled {
    [FUtilities setLoggingEnabled:enabled];
    FFLog(@"I-RDB024001", @"BUILD Version: %@", [FIRDatabase buildVersion]);
}

- (id)initWithApp:(FIRApp *)app
         repoInfo:(FRepoInfo *)info
           config:(FIRDatabaseConfig *)config {
    self = [super init];
    if (self != nil) {
        self->_repoInfo = info;
        self->_config = config;
        self->_app = app;
    }
    return self;
}

- (FIRDatabaseReference *)reference {
    [self ensureRepo];

    return [[FIRDatabaseReference alloc] initWithRepo:self.repo
                                                 path:[FPath empty]];
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
        [NSException raise:@"InvalidDatabaseURL"
                    format:@"Invalid nil url passed to referenceFromURL:"];
    }
    FParsedUrl *parsedUrl = [FUtilities parseUrl:databaseUrl];
    [FValidation validateFrom:@"referenceFromURL:" validURL:parsedUrl];
    if (![parsedUrl.repoInfo.host isEqualToString:_repoInfo.host]) {
        [NSException
             raise:@"InvalidDatabaseURL"
            format:
                @"Invalid URL (%@) passed to getReference(). URL was expected "
                 "to match configured Database URL: %@",
                databaseUrl, [self reference].URL];
    }
    return [[FIRDatabaseReference alloc] initWithRepo:self.repo
                                                 path:parsedUrl.path];
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

- (void)assertUnfrozen:(NSString *)methodName {
    if (self.repo != nil) {
        [NSException
             raise:@"FIRDatabaseAlreadyInUse"
            format:@"Calls to %@ must be made before any other usage of "
                    "FIRDatabase instance.",
                   methodName];
    }
}

- (void)ensureRepo {
    if (self.repo == nil) {
        self.repo = [FRepoManager createRepo:self.repoInfo
                                      config:self.config
                                    database:self];
    }
}

@end
