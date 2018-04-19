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

@class FUNFakeOptions;

NS_ASSUME_NONNULL_BEGIN

/**
 * FUNFakeApp is a mock app to use for tests.
 */
@interface FUNFakeApp : NSObject

- (id)init NS_UNAVAILABLE;

- (instancetype)initWithProjectID:(NSString *)projectID;

- (instancetype)initWithProjectID:(NSString *)projectID
                            token:(NSString *_Nullable)token NS_DESIGNATED_INITIALIZER;

@property(nonatomic, strong, readonly) FUNFakeOptions *options;

@end

NS_ASSUME_NONNULL_END
