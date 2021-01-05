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

#import "Functions/FirebaseFunctions/Public/FirebaseFunctions/FIRHTTPSCallable.h"
#import "Functions/FirebaseFunctions/FIRHTTPSCallable+Internal.h"

#import "Functions/FirebaseFunctions/FIRFunctions+Internal.h"
#import "Functions/FirebaseFunctions/FUNUsageValidation.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRHTTPSCallableResult

- (instancetype)initWithData:(id)data {
  self = [super init];
  if (self) {
    _data = data;
  }
  return self;
}

@end

@interface FIRHTTPSCallable () {
  // The functions client to use for making calls.
  FIRFunctions *_functions;
  // The name of the http endpoint this reference refers to.
  NSString *_name;
}

@end

@implementation FIRHTTPSCallable

- (instancetype)initWithFunctions:(FIRFunctions *)functions name:(NSString *)name {
  self = [super init];
  if (self) {
    if (!name) {
      FUNThrowInvalidArgument(@"FIRHTTPSCallable name cannot be nil.");
    }
    _name = [name copy];
    _functions = functions;
    _timeoutInterval = 70.0;
  }
  return self;
}

- (void)callWithCompletion:(void (^)(FIRHTTPSCallableResult *_Nullable result,
                                     NSError *_Nullable error))completion {
  [self callWithObject:nil completion:completion];
}

- (void)callWithObject:(nullable id)data
            completion:(void (^)(FIRHTTPSCallableResult *_Nullable result,
                                 NSError *_Nullable error))completion {
  [_functions callFunction:_name
                withObject:data
                   timeout:self.timeoutInterval
                completion:completion];
}

@end

NS_ASSUME_NONNULL_END
