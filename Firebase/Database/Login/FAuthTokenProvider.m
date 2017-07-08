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

#import "FAuthTokenProvider.h"
#import "FUtilities.h"
#import "FIRLogger.h"
#import "FIRDatabaseQuery_Private.h"
#import "FIRNoopAuthTokenProvider.h"

static NSString *const FIRAuthStateDidChangeInternalNotification = @"FIRAuthStateDidChangeInternalNotification";
static NSString *const FIRAuthStateDidChangeInternalNotificationTokenKey = @"FIRAuthStateDidChangeInternalNotificationTokenKey";


/**
 * This is a hack that defines all the methods we need from FIRFirebaseApp. At runtime we use reflection to get an
 * actual instance of FIRFirebaseApp. Since protocols don't carry any runtime information and selectors are invoked
 * by name we can write code against this protocol as long as the method signatures of FIRFirebaseApp don't change.
 */
@protocol FIRFirebaseAppLike <NSObject>

- (void)getTokenForcingRefresh:(BOOL)forceRefresh withCallback:(void (^)(NSString *_Nullable token, NSError *_Nullable error))callback;

@end


/**
 * This is a hack that defines all the methods we need from FIRAuth.
 */
@protocol FIRFirebaseAuthLike <NSObject>

- (id<FIRFirebaseAppLike>) app;

@end

/**
 * This is a hack that copies the definitions of Firebase Auth error codes. If the error codes change in the original code, this
 * will break at runtime due to undefined behavior!
 */
typedef NS_ENUM(NSUInteger, FIRErrorCode) {
    /*! @var FIRErrorCodeNoAuth
     @brief Represents the case where an auth-related message was sent to a @c FIRFirebaseApp
     instance which has no associated @c FIRAuth instance.
     */
    FIRErrorCodeNoAuth,

    /*! @var FIRErrorCodeNoSignedInUser
     @brief Represents the case where an attempt was made to fetch a token when there is no signed
     in user.
     */
    FIRErrorCodeNoSignedInUser,
};


@interface FAuthStateListenerWrapper : NSObject

@property (nonatomic, copy) fbt_void_nsstring listener;

@property (nonatomic, weak) id<FIRFirebaseAppLike> app;

@end

@implementation FAuthStateListenerWrapper

- (instancetype) initWithListener:(fbt_void_nsstring)listener app:(id<FIRFirebaseAppLike>)app {
    self = [super init];
    if (self != nil) {
        self->_listener = listener;
        self->_app = app;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(authStateDidChangeNotification:)
                                                     name:FIRAuthStateDidChangeInternalNotification
                                                   object:nil];
    }
    return self;
}

- (void) authStateDidChangeNotification:(NSNotification *)notification {
    id<FIRFirebaseAuthLike> auth = notification.object;
    if (auth.app == self->_app) {
        NSDictionary *userInfo = notification.userInfo;
        NSString *token = userInfo[FIRAuthStateDidChangeInternalNotificationTokenKey];
        dispatch_async([FIRDatabaseQuery sharedQueue], ^{
            self.listener(token);
        });
    }
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end


@interface FIRFirebaseAuthTokenProvider : NSObject <FAuthTokenProvider>

@property (nonatomic, strong) id<FIRFirebaseAppLike> app;
/** Strong references to the auth listeners as they are only weak in FIRFirebaseApp */
@property (nonatomic, strong) NSMutableArray *authListeners;

- (instancetype) initWithFirebaseApp:(id<FIRFirebaseAppLike>)app;

@end

@implementation FIRFirebaseAuthTokenProvider

- (instancetype) initWithFirebaseApp:(id<FIRFirebaseAppLike>)app {
    self = [super init];
    if (self != nil) {
        self->_app = app;
        self->_authListeners = [NSMutableArray array];
    }
    return self;
}

- (void) fetchTokenForcingRefresh:(BOOL)forceRefresh withCallback:(fbt_void_nsstring_nserror)callback {
    // TODO: Don't fetch token if there is no current user
    [self.app getTokenForcingRefresh:forceRefresh withCallback:^(NSString * _Nullable token, NSError * _Nullable error) {
        dispatch_async([FIRDatabaseQuery sharedQueue], ^{
            if (error != nil) {
                if (error.code == FIRErrorCodeNoAuth) {
                    FFLog(@"I-RDB073001", @"Firebase Auth is not configured, not going to use authentication.");
                    callback(nil, nil);
                } else if (error.code == FIRErrorCodeNoSignedInUser) {
                    // No signed in user is an expected case, callback as success with no token
                    callback(nil, nil);
                } else {
                    callback(nil, error);
                }
            } else {
                callback(token, nil);
            }
        });
    }];
}

- (void) listenForTokenChanges:(_Nonnull fbt_void_nsstring)listener {
    FAuthStateListenerWrapper *wrapper = [[FAuthStateListenerWrapper alloc] initWithListener:listener app:self.app];
    [self.authListeners addObject:wrapper];
}

@end

@implementation FAuthTokenProvider

+ (id<FAuthTokenProvider>) authTokenProviderForApp:(id)app {
    return [[FIRFirebaseAuthTokenProvider alloc] initWithFirebaseApp:app];
}

@end
