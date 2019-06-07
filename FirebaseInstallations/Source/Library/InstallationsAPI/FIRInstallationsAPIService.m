/*
 * Copyright 2019 Google
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

#import "FIRInstallationsAPIService.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

@interface FIRInstallationsAPIService ()
@property(nonatomic, readonly) NSURLSession *urlSession;
@end

@implementation FIRInstallationsAPIService

- (instancetype)init
{
  NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
  return [self initWithURLSession:urlSession];
}

/// The initializer for tests.
- (instancetype)initWithURLSession:(NSURLSession *)urlSession
{
  self = [super init];
  if (self) {
    _urlSession = urlSession;
  }
  return self;
}

#pragma mark - Public

- (FBLPromise<FIRInstallationsItem *> *)registerInstallation:(FIRInstallationsItem *)installation {
  // TODO: Implement.
  return [FBLPromise resolvedWith:installation];
}

#pragma mark - Register Installation

- (NSURLRequest *)registerRequestWithInstallation:(FIRInstallationsItem *)installation {
  return nil;
}

@end
