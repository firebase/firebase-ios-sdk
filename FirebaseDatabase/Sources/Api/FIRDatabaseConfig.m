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

#import "FirebaseDatabase/Sources/Api/FIRDatabaseConfig.h"

#import "FirebaseDatabase/Sources/FIRDatabaseConfig_Private.h"
#import "FirebaseDatabase/Sources/Login/FIRDatabaseConnectionContextProvider.h"

@interface FIRDatabaseConfig (Private)

@property(nonatomic, strong, readwrite) NSString *sessionIdentifier;
@property(nonatomic, strong, readwrite) NSString *googleAppID;

@end

@implementation FIRDatabaseConfig

- (id)init {
    [NSException raise:NSInvalidArgumentException
                format:@"Can't create config objects!"];
    return nil;
}

- (id)initWithSessionIdentifier:(NSString *)identifier
                    googleAppID:(NSString *)googleAppID
                contextProvider:
                    (id<FIRDatabaseConnectionContextProvider>)contextProvider {
    self = [super init];
    if (self != nil) {
        self->_sessionIdentifier = identifier;
        self->_callbackQueue = dispatch_get_main_queue();
        self->_googleAppID = googleAppID;
        self->_persistenceCacheSizeBytes =
            10 * 1024 * 1024; // Default cache size is 10MB
        self->_contextProvider = contextProvider;
    }
    return self;
}

- (void)assertUnfrozen {
    if (self.isFrozen) {
        [NSException raise:NSGenericException
                    format:@"Can't modify config objects after they are in use "
                           @"for FIRDatabaseReferences."];
    }
}

- (void)setContextProvider:
    (id<FIRDatabaseConnectionContextProvider>)contextProvider {
    [self assertUnfrozen];
    self->_contextProvider = contextProvider;
}

- (void)setPersistenceEnabled:(BOOL)persistenceEnabled {
    [self assertUnfrozen];
    self->_persistenceEnabled = persistenceEnabled;
}

- (void)setPersistenceCacheSizeBytes:(NSUInteger)persistenceCacheSizeBytes {
    [self assertUnfrozen];
    // Can't be less than 1MB
    if (persistenceCacheSizeBytes < 1024 * 1024) {
        [NSException raise:NSInvalidArgumentException
                    format:@"The minimum cache size must be at least 1MB"];
    }
    if (persistenceCacheSizeBytes > 100 * 1024 * 1024) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Firebase Database currently doesn't support a "
                           @"cache size larger than 100MB"];
    }
    self->_persistenceCacheSizeBytes = persistenceCacheSizeBytes;
}

- (void)setCallbackQueue:(dispatch_queue_t)callbackQueue {
    [self assertUnfrozen];
    self->_callbackQueue = callbackQueue;
}

- (void)freeze {
    self->_isFrozen = YES;
}

@end
