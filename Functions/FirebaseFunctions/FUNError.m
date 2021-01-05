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

#import "Functions/FirebaseFunctions/FUNError.h"

#import "Functions/FirebaseFunctions/FUNSerializer.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const FIRFunctionsErrorDomain = @"com.firebase.functions";
NSString *const FIRFunctionsErrorDetailsKey = @"details";

/**
 * Takes an HTTP status code and returns the corresponding FIRFunctionsErrorCode error code.
 * This is the standard HTTP status code -> error mapping defined in:
 * https://github.com/googleapis/googleapis/blob/master/google/rpc/code.proto
 * @param status An HTTP status code.
 * @return The corresponding error code, or FIRFunctionsErrorCodeUnknown if none.
 */
FIRFunctionsErrorCode FIRFunctionsErrorCodeForHTTPStatus(NSInteger status) {
  switch (status) {
    case 200:
      return FIRFunctionsErrorCodeOK;
    case 400:
      return FIRFunctionsErrorCodeInvalidArgument;
    case 401:
      return FIRFunctionsErrorCodeUnauthenticated;
    case 403:
      return FIRFunctionsErrorCodePermissionDenied;
    case 404:
      return FIRFunctionsErrorCodeNotFound;
    case 409:
      return FIRFunctionsErrorCodeAborted;
    case 429:
      return FIRFunctionsErrorCodeResourceExhausted;
    case 499:
      return FIRFunctionsErrorCodeCancelled;
    case 500:
      return FIRFunctionsErrorCodeInternal;
    case 501:
      return FIRFunctionsErrorCodeUnimplemented;
    case 503:
      return FIRFunctionsErrorCodeUnavailable;
    case 504:
      return FIRFunctionsErrorCodeDeadlineExceeded;
  }
  return FIRFunctionsErrorCodeInternal;
}

/**
 * Takes the name of an error code and returns the enum value for it.
 * @param name An error name.
 * @return The error code with this name, or FIRFunctionsErrorCodeUnknown if none.
 */
NSNumber *FIRFunctionsErrorCodeForName(NSString *name) {
  static NSDictionary<NSString *, NSNumber *> *errors;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    errors = @{
      @"OK" : @(FIRFunctionsErrorCodeOK),
      @"CANCELLED" : @(FIRFunctionsErrorCodeCancelled),
      @"UNKNOWN" : @(FIRFunctionsErrorCodeUnknown),
      @"INVALID_ARGUMENT" : @(FIRFunctionsErrorCodeInvalidArgument),
      @"DEADLINE_EXCEEDED" : @(FIRFunctionsErrorCodeDeadlineExceeded),
      @"NOT_FOUND" : @(FIRFunctionsErrorCodeNotFound),
      @"ALREADY_EXISTS" : @(FIRFunctionsErrorCodeAlreadyExists),
      @"PERMISSION_DENIED" : @(FIRFunctionsErrorCodePermissionDenied),
      @"RESOURCE_EXHAUSTED" : @(FIRFunctionsErrorCodeResourceExhausted),
      @"FAILED_PRECONDITION" : @(FIRFunctionsErrorCodeFailedPrecondition),
      @"ABORTED" : @(FIRFunctionsErrorCodeAborted),
      @"OUT_OF_RANGE" : @(FIRFunctionsErrorCodeOutOfRange),
      @"UNIMPLEMENTED" : @(FIRFunctionsErrorCodeUnimplemented),
      @"INTERNAL" : @(FIRFunctionsErrorCodeInternal),
      @"UNAVAILABLE" : @(FIRFunctionsErrorCodeUnavailable),
      @"DATA_LOSS" : @(FIRFunctionsErrorCodeDataLoss),
      @"UNAUTHENTICATED" : @(FIRFunctionsErrorCodeUnauthenticated),
    };
  });
  return errors[name];
}

/**
 * Takes a FIRFunctionsErrorCode and returns an English description of it.
 * @param code An error code.
 * @return A description of the code, or "UNKNOWN" if none.
 */
NSString *FUNDescriptionForErrorCode(FIRFunctionsErrorCode code) {
  switch (code) {
    case FIRFunctionsErrorCodeOK:
      return @"OK";
    case FIRFunctionsErrorCodeCancelled:
      return @"CANCELLED";
    case FIRFunctionsErrorCodeUnknown:
      return @"UNKNOWN";
    case FIRFunctionsErrorCodeInvalidArgument:
      return @"INVALID ARGUMENT";
    case FIRFunctionsErrorCodeDeadlineExceeded:
      return @"DEADLINE EXCEEDED";
    case FIRFunctionsErrorCodeNotFound:
      return @"NOT FOUND";
    case FIRFunctionsErrorCodeAlreadyExists:
      return @"ALREADY EXISTS";
    case FIRFunctionsErrorCodePermissionDenied:
      return @"PERMISSION DENIED";
    case FIRFunctionsErrorCodeResourceExhausted:
      return @"RESOURCE EXHAUSTED";
    case FIRFunctionsErrorCodeFailedPrecondition:
      return @"FAILED PRECONDITION";
    case FIRFunctionsErrorCodeAborted:
      return @"ABORTED";
    case FIRFunctionsErrorCodeOutOfRange:
      return @"OUT OF RANGE";
    case FIRFunctionsErrorCodeUnimplemented:
      return @"UNIMPLEMENTED";
    case FIRFunctionsErrorCodeInternal:
      return @"INTERNAL";
    case FIRFunctionsErrorCodeUnavailable:
      return @"UNAVAILABLE";
    case FIRFunctionsErrorCodeDataLoss:
      return @"DATA LOSS";
    case FIRFunctionsErrorCodeUnauthenticated:
      return @"UNAUTHENTICATED";
  }
  return @"UNKNOWN";
}

NSError *_Nullable FUNErrorForCode(FIRFunctionsErrorCode code) {
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : FUNDescriptionForErrorCode(code)};
  return [NSError errorWithDomain:FIRFunctionsErrorDomain code:code userInfo:userInfo];
}

NSError *_Nullable FUNErrorForResponse(NSInteger status,
                                       NSData *_Nullable body,
                                       FUNSerializer *serializer) {
  // Start with reasonable defaults from the status code.
  FIRFunctionsErrorCode code = FIRFunctionsErrorCodeForHTTPStatus(status);
  NSString *description = FUNDescriptionForErrorCode(code);
  id details = nil;

  // Then look through the body for explicit details.
  if (body) {
    NSError *parseError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:body options:0 error:&parseError];
    if (!parseError && [json isKindOfClass:[NSDictionary class]]) {
      id errorDetails = json[@"error"];
      if ([errorDetails isKindOfClass:[NSDictionary class]]) {
        if ([errorDetails[@"status"] isKindOfClass:[NSString class]]) {
          NSNumber *codeNumber = FIRFunctionsErrorCodeForName(errorDetails[@"status"]);
          if (codeNumber == nil) {
            // If the code in the body is invalid, treat the whole response as malformed.
            return FUNErrorForCode(FIRFunctionsErrorCodeInternal);
          }
          code = codeNumber.intValue;
          // The default description needs to be updated for the new code.
          description = FUNDescriptionForErrorCode(code);
        }
        if ([errorDetails[@"message"] isKindOfClass:[NSString class]]) {
          description = (NSString *)errorDetails[@"message"];
        }
        details = errorDetails[@"details"];
        if (details) {
          NSError *decodeError = nil;
          details = [serializer decode:details error:&decodeError];
          // Just ignore the details if there an error decoding them.
        }
      }
    }
  }

  if (code == FIRFunctionsErrorCodeOK) {
    // Technically, there's an edge case where a developer could explicitly return an error code of
    // OK, and we will treat it as success, but that seems reasonable.
    return nil;
  }

  NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
  userInfo[NSLocalizedDescriptionKey] = description;
  if (details) {
    userInfo[FIRFunctionsErrorDetailsKey] = details;
  }
  return [NSError errorWithDomain:FIRFunctionsErrorDomain code:code userInfo:userInfo];
}

NS_ASSUME_NONNULL_END
