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

#import "FirebaseDatabase/Tests/Helpers/FIRTestAuthTokenProvider.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"

@interface FIRTestAuthTokenProvider ()

@property(nonatomic, strong) NSMutableArray *listeners;

@end

@implementation FIRTestAuthTokenProvider

- (instancetype)initWithToken:(NSString *)token {
  self = [super init];
  if (self != nil) {
    self.listeners = [NSMutableArray array];
    self.token = token;
  }
  return self;
}

- (void)setToken:(NSString *)token {
  self->_token = token;
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    [self.listeners enumerateObjectsUsingBlock:^(fbt_void_nsstring _Nonnull listener,
                                                 NSUInteger idx, BOOL *_Nonnull stop) {
      listener(token);
    }];
  });
}

- (void)fetchTokenForcingRefresh:(BOOL)forceRefresh
                    withCallback:(fbt_void_nsstring_nserror)callback {
  if (forceRefresh) {
    self.token = self.nextToken;
  }
  // Simulate delay
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_MSEC)),
                 [FIRDatabaseQuery sharedQueue], ^{
                   callback(self.token, nil);
                 });
}

- (void)listenForTokenChanges:(fbt_void_nsstring)listener {
  [self.listeners addObject:[listener copy]];
}

@end
