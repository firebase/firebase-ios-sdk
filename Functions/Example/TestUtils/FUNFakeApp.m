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

#import "FUNFakeApp.h"

NS_ASSUME_NONNULL_BEGIN

@interface FUNFakeOptions : NSObject

@property(nonatomic, readonly, copy) NSString *projectID;

- (id)init NS_UNAVAILABLE;

- (instancetype)initWithProjectID:(NSString *)projectID NS_DESIGNATED_INITIALIZER;

@end

@implementation FUNFakeOptions

- (instancetype)initWithProjectID:(NSString *)projectID {
  self = [super init];
  if (self) {
    self->_projectID = [projectID copy];
  }
  return self;
}

@end

@interface FUNFakeApp () {
  NSString *_token;
}
@end

@implementation FUNFakeApp

- (instancetype)initWithProjectID:(NSString *)projectID {
  return [self initWithProjectID:projectID token:nil];
}

- (instancetype)initWithProjectID:(NSString *)projectID token:(NSString *_Nullable)token {
  self = [super init];
  if (self) {
    _options = [[FUNFakeOptions alloc] initWithProjectID:projectID];
    _token = [token copy];
  }
  return self;
}

- (void)getTokenForcingRefresh:(BOOL)forceRefresh
                  withCallback:
                      (void (^)(NSString *_Nullable token, NSError *_Nullable error))callback {
  callback(_token, nil);
}

@end

NS_ASSUME_NONNULL_END
