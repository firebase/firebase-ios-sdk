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

#import "FirebaseDatabase/Sources/Api/Private/FTypedefs_Private.h"
#import "FirebaseDatabase/Sources/Utilities/FTypedefs.h"

@protocol FIRAuthInterop;

@protocol FAuthTokenProvider <NSObject>

- (void)fetchTokenForcingRefresh:(BOOL)forceRefresh
                    withCallback:(fbt_void_nsstring_nserror)callback;

- (void)listenForTokenChanges:(fbt_void_nsstring)listener;

@end

@interface FAuthTokenProvider : NSObject

+ (id<FAuthTokenProvider>)authTokenProviderWithAuth:(id<FIRAuthInterop>)auth;

- (instancetype)init NS_UNAVAILABLE;

@end
