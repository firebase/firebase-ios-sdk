// Copyright 2022 Google LLC
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

#import <XCTest/XCTest.h>

#import <FirebaseFunctions/FirebaseFunctions-Swift.h>
#import "FirebaseCore/FirebaseCore.h"

@interface ObjCPPAPICoverage : XCTestCase
@end

@implementation ObjCPPAPICoverage

- (void)apis {
#pragma mark - Functions

  FIRApp *app = [FIRApp defaultApp];
  FIRFunctions *func = [FIRFunctions functions];
  func = [FIRFunctions functionsForApp:app];
  func = [FIRFunctions functionsForRegion:@"my-region"];
  func = [FIRFunctions functionsForCustomDomain:@"my-domain"];
  func = [FIRFunctions functionsForApp:app region:@"my-region"];
  func = [FIRFunctions functionsForApp:app customDomain:@"my-domain"];

  FIRHTTPSCallable *callable = [func HTTPSCallableWithName:@"name"];
  NSURL *url = [NSURL URLWithString:@"http://host:123/project/location/name"];
  callable = [func HTTPSCallableWithURL:url];

  FIRHTTPSCallableOptions *options =
      [[FIRHTTPSCallableOptions alloc] initWithRequireLimitedUseAppCheckTokens:YES];
  __unused BOOL requireLimitedUseAppCheckTokens = options.requireLimitedUseAppCheckTokens;
  callable = [func HTTPSCallableWithURL:url options:options];
  callable = [func HTTPSCallableWithName:@"name" options:options];

  [func useEmulatorWithHost:@"host" port:123];

#pragma mark - HTTPSCallable and HTTPSCallableResult
  [callable
      callWithCompletion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
        __unused id data = result.data;
      }];
  [callable callWithObject:nil
                completion:^(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error) {
                  [result data];
                }];
  callable.timeoutInterval = 60;
  [callable timeoutInterval];
}

#pragma mark - FunctionsError

- (FIRFunctionsErrorCode)errorCodes:(NSError *)error {
  switch (error.code) {
    case FIRFunctionsErrorCodeOK:
    case FIRFunctionsErrorCodeCancelled:
    case FIRFunctionsErrorCodeUnknown:
    case FIRFunctionsErrorCodeInvalidArgument:
    case FIRFunctionsErrorCodeDeadlineExceeded:
    case FIRFunctionsErrorCodeNotFound:
    case FIRFunctionsErrorCodeAlreadyExists:
    case FIRFunctionsErrorCodePermissionDenied:
    case FIRFunctionsErrorCodeResourceExhausted:
    case FIRFunctionsErrorCodeFailedPrecondition:
    case FIRFunctionsErrorCodeAborted:
    case FIRFunctionsErrorCodeOutOfRange:
    case FIRFunctionsErrorCodeUnimplemented:
    case FIRFunctionsErrorCodeInternal:
    case FIRFunctionsErrorCodeUnavailable:
    case FIRFunctionsErrorCodeDataLoss:
    case FIRFunctionsErrorCodeUnauthenticated:
      return (FIRFunctionsErrorCode)error.code;
  }
  return (FIRFunctionsErrorCode)error.code;
}
@end
