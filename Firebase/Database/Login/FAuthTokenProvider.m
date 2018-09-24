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
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRLogger.h>
#import "FIRDatabaseQuery_Private.h"
#import "FIRNoopAuthTokenProvider.h"

@interface FAuthStateListenerWrapper : NSObject

@property (nonatomic, copy) fbt_void_nsstring listener;

@property (nonatomic, weak) FIRApp *app;

@end

@implementation FAuthStateListenerWrapper

- (instancetype) initWithListener:(fbt_void_nsstring)listener app:(FIRApp *)app {
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
    NSDictionary *userInfo = notification.userInfo;
    FIRApp *authApp = userInfo[FIRAuthStateDidChangeInternalNotificationAppKey];
    if (authApp == self.app) {
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

@property (nonatomic, strong) FIRApp *app;
/** Strong references to the auth listeners as they are only weak in FIRFirebaseApp */
@property (nonatomic, strong) NSMutableArray *authListeners;

- (instancetype) initWithFirebaseApp:(FIRApp *)app;

@end

@implementation FIRFirebaseAuthTokenProvider

- (instancetype) initWithFirebaseApp:(FIRApp *)app {
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
            callback(token, error);
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
