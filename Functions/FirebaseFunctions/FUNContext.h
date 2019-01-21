//
// Copyright 2017 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

@class FIRApp;
@protocol FIRAuthInterop;

NS_ASSUME_NONNULL_BEGIN

/**
 * FUNContext is a helper class for gathering metadata for a function call.
 */
@interface FUNContext : NSObject
- (id)init NS_UNAVAILABLE;
@property(nonatomic, copy, nullable, readonly) NSString *authToken;
@property(nonatomic, copy, nullable, readonly) NSString *instanceIDToken;
@end

/**
 * A FUNContextProvider gathers metadata and creats a FUNContext.
 */
@interface FUNContextProvider : NSObject

- (id)init NS_UNAVAILABLE;

- (instancetype)initWithAuth:(nullable id<FIRAuthInterop>)auth NS_DESIGNATED_INITIALIZER;

- (void)getContext:(void (^)(FUNContext *_Nullable context, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
