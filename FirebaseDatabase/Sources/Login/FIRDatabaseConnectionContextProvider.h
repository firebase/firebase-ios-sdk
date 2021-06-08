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

#import <Foundation/Foundation.h>

#import "FirebaseDatabase/Sources/Api/Private/FTypedefs_Private.h"
#import "FirebaseDatabase/Sources/Utilities/FTypedefs.h"

@protocol FIRAppCheckInterop;
@protocol FIRAuthInterop;

NS_ASSUME_NONNULL_BEGIN

@interface FIRDatabaseConnectionContext : NSObject
/// Auth token if available.
@property(nonatomic, nullable) NSString *authToken;

/// App check token if available.
@property(nonatomic, nullable) NSString *appCheckToken;

- (instancetype)initWithAuthToken:(nullable NSString *)authToken
                    appCheckToken:(nullable NSString *)appCheckToken;

@end

@protocol FIRDatabaseConnectionContextProvider <NSObject>

- (void)
    fetchContextForcingRefresh:(BOOL)forceRefresh
                  withCallback:
                      (void (^)(FIRDatabaseConnectionContext *_Nullable context,
                                NSError *_Nullable error))callback;

/// Adds a listener to the Auth token updates.
/// @param listener A block that will be invoked each time the Auth token is
/// updated.
- (void)listenForAuthTokenChanges:(fbt_void_nsstring)listener;

/// Adds a listener to the FAC token updates.
/// @param listener A block that will be invoked each time the FAC token is
/// updated.
- (void)listenForAppCheckTokenChanges:(fbt_void_nsstring)listener;

@end

@interface FIRDatabaseConnectionContextProvider
    : NSObject <FIRDatabaseConnectionContextProvider>

+ (id<FIRDatabaseConnectionContextProvider>)
    contextProviderWithAuth:(nullable id<FIRAuthInterop>)auth
                   appCheck:(nullable id<FIRAppCheckInterop>)appCheck;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
