/*
 * Copyright 2021 Google LLC
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

#import "FirebaseDatabase/Sources/Login/FIRDatabaseConnectionContextProvider.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseAppCheck/Sources/Interop/FIRAppCheckInterop.h"
#import "FirebaseAppCheck/Sources/Interop/FIRAppCheckTokenResultInterop.h"
#import "Interop/Auth/Public/FIRAuthInterop.h"

#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"

NS_ASSUME_NONNULL_BEGIN

@interface FAuthStateListenerWrapper : NSObject

@property(nonatomic, copy) fbt_void_nsstring listener;
@property(nonatomic, weak) id<FIRAuthInterop> auth;

@end

@implementation FAuthStateListenerWrapper

- (instancetype)initWithListener:(fbt_void_nsstring)listener
                            auth:(id<FIRAuthInterop>)auth {
    self = [super init];
    if (self != nil) {
        self->_listener = listener;
        self->_auth = auth;
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(authStateDidChangeNotification:)
                   name:FIRAuthStateDidChangeInternalNotification
                 object:nil];
    }
    return self;
}

- (void)authStateDidChangeNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    if (notification.object == self.auth) {
        NSString *token =
            userInfo[FIRAuthStateDidChangeInternalNotificationTokenKey];
        dispatch_async([FIRDatabaseQuery sharedQueue], ^{
          self.listener(token);
        });
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

@implementation FIRDatabaseConnectionContext

- (instancetype)initWithAuthToken:(nullable NSString *)authToken
                    appCheckToken:(nullable NSString *)appCheckToken {
    self = [super init];
    if (self) {
        _authToken = [authToken copy];
        _appCheckToken = [appCheckToken copy];
    }
    return self;
}

@end

@interface FIRDatabaseConnectionContextProvider ()

@property(nonatomic, strong) id<FIRAppCheckInterop> appCheck;
@property(nonatomic, strong) id<FIRAuthInterop> auth;

/// Strong references to the auth listeners as they are only weak in
/// FIRFirebaseApp.
@property(nonatomic, readonly) NSMutableArray *authListeners;

/// Observer objects returned by
/// `-[NSNotificationCenter addObserverForName:object:queue:usingBlock:]`
/// method. Required to cleanup the observers on dealloc.
@property(nonatomic, readonly) NSMutableArray *appCheckNotificationObservers;

/// An NSOperationQueue to call listeners on.
@property(nonatomic, readonly) NSOperationQueue *listenerQueue;

@end

@implementation FIRDatabaseConnectionContextProvider

- (instancetype)initWithAuth:(nullable id<FIRAuthInterop>)auth
                    appCheck:(nullable id<FIRAppCheckInterop>)appCheck {
    self = [super init];
    if (self != nil) {
        self->_appCheck = appCheck;
        self->_auth = auth;
        self->_authListeners = [NSMutableArray array];
        self->_appCheckNotificationObservers = [NSMutableArray array];
        self->_listenerQueue = [[NSOperationQueue alloc] init];
        self->_listenerQueue.underlyingQueue = [FIRDatabaseQuery sharedQueue];
    }
    return self;
}

- (void)dealloc {
    @synchronized(self) {
        // Make sure notification observers are removed from
        // NSNotificationCenter.
        for (id notificationObserver in self.appCheckNotificationObservers) {
            [NSNotificationCenter.defaultCenter
                removeObserver:notificationObserver];
        }
    }
}

- (void)
    fetchContextForcingRefresh:(BOOL)forceRefresh
                  withCallback:
                      (void (^)(FIRDatabaseConnectionContext *_Nullable context,
                                NSError *_Nullable error))callback {

    if (self.auth == nil && self.appCheck == nil) {
        // Nothing to fetch. Finish straight away.
        callback(nil, nil);
        return;
    }

    // Use dispatch group to call the callback when both Auth and FAC operations
    // finished.
    dispatch_group_t dispatchGroup = dispatch_group_create();

    __block NSString *authToken;
    __block NSString *appCheckToken;
    __block NSError *authError;

    if (self.auth) {
        dispatch_group_enter(dispatchGroup);
        [self.auth getTokenForcingRefresh:forceRefresh
                             withCallback:^(NSString *_Nullable token,
                                            NSError *_Nullable error) {
                               authToken = token;
                               authError = error;

                               dispatch_group_leave(dispatchGroup);
                             }];
    }

    if (self.appCheck) {
        dispatch_group_enter(dispatchGroup);
        [self.appCheck
            getTokenForcingRefresh:forceRefresh
                        completion:^(
                            id<FIRAppCheckTokenResultInterop> _Nonnull tokenResult) {
                          appCheckToken = tokenResult.token;
                          if (tokenResult.error) {
                              FFLog(@"I-RDB096001",
                                    @"Failed to fetch App Check token: %@",
                                    tokenResult.error);
                          }
                          dispatch_group_leave(dispatchGroup);
                        }];
    }

    dispatch_group_notify(dispatchGroup, [FIRDatabaseQuery sharedQueue], ^{
      __auto_type context = [[FIRDatabaseConnectionContext alloc]
          initWithAuthToken:authToken
              appCheckToken:appCheckToken];
      // Pass only a possible Auth error. App Check errors should not change the
      // database SDK behaviour at this point as the App Check enforcement is
      // controlled on the backend.
      callback(context, authError);
    });
}

- (void)listenForAuthTokenChanges:(_Nonnull fbt_void_nsstring)listener {
    FAuthStateListenerWrapper *wrapper =
        [[FAuthStateListenerWrapper alloc] initWithListener:listener
                                                       auth:self.auth];
    [self.authListeners addObject:wrapper];
}

- (void)listenForAppCheckTokenChanges:(fbt_void_nsstring)listener {
    if (self.appCheck == nil) {
        return;
    }
    NSString *appCheckTokenKey = [self.appCheck notificationTokenKey];
    __auto_type notificationObserver = [NSNotificationCenter.defaultCenter
        addObserverForName:[self.appCheck tokenDidChangeNotificationName]
                    object:self.appCheck
                     queue:self.listenerQueue
                usingBlock:^(NSNotification *_Nonnull notification) {
                  NSString *appCheckToken =
                      notification.userInfo[appCheckTokenKey];
                  listener(appCheckToken);
                }];

    @synchronized(self) {
        [self.appCheckNotificationObservers addObject:notificationObserver];
    }
}

+ (id<FIRDatabaseConnectionContextProvider>)
    contextProviderWithAuth:(nullable id<FIRAuthInterop>)auth
                   appCheck:(nullable id<FIRAppCheckInterop>)appCheck {
    return [[self alloc] initWithAuth:auth appCheck:appCheck];
}

@end

NS_ASSUME_NONNULL_END
