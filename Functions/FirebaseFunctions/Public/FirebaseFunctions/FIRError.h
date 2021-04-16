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

NS_ASSUME_NONNULL_BEGIN

// The error domain for codes in the FIRFunctionsErrorCode enum.
FOUNDATION_EXPORT NSString *const FIRFunctionsErrorDomain NS_SWIFT_NAME(FunctionsErrorDomain);

// The key for finding error details in the NSError userInfo.
FOUNDATION_EXPORT NSString *const FIRFunctionsErrorDetailsKey
    NS_SWIFT_NAME(FunctionsErrorDetailsKey);

/**
 * The set of error status codes that can be returned from a Callable HTTPS tigger. These are the
 * canonical error codes for Google APIs, as documented here:
 * https://github.com/googleapis/googleapis/blob/master/google/rpc/code.proto#L26
 */
typedef NS_ENUM(NSInteger, FIRFunctionsErrorCode) {
  /** The operation completed successfully. */
  FIRFunctionsErrorCodeOK = 0,
  /** The operation was cancelled (typically by the caller). */
  FIRFunctionsErrorCodeCancelled = 1,
  /** Unknown error or an error from a different error domain. */
  FIRFunctionsErrorCodeUnknown = 2,
  /**
   * Client specified an invalid argument. Note that this differs from `FailedPrecondition`.
   * `InvalidArgument` indicates arguments that are problematic regardless of the state of the
   * system (e.g., an invalid field name).
   */
  FIRFunctionsErrorCodeInvalidArgument = 3,
  /**
   * Deadline expired before operation could complete. For operations that change the state of the
   * system, this error may be returned even if the operation has completed successfully. For
   * example, a successful response from a server could have been delayed long enough for the
   * deadline to expire.
   */
  FIRFunctionsErrorCodeDeadlineExceeded = 4,
  /** Some requested document was not found. */
  FIRFunctionsErrorCodeNotFound = 5,
  /** Some document that we attempted to create already exists. */
  FIRFunctionsErrorCodeAlreadyExists = 6,
  /** The caller does not have permission to execute the specified operation. */
  FIRFunctionsErrorCodePermissionDenied = 7,
  /**
   * Some resource has been exhausted, perhaps a per-user quota, or perhaps the entire file system
   * is out of space.
   */
  FIRFunctionsErrorCodeResourceExhausted = 8,
  /**
   * Operation was rejected because the system is not in a state required for the operation's
   * execution.
   */
  FIRFunctionsErrorCodeFailedPrecondition = 9,
  /**
   * The operation was aborted, typically due to a concurrency issue like transaction aborts, etc.
   */
  FIRFunctionsErrorCodeAborted = 10,
  /** Operation was attempted past the valid range. */
  FIRFunctionsErrorCodeOutOfRange = 11,
  /** Operation is not implemented or not supported/enabled. */
  FIRFunctionsErrorCodeUnimplemented = 12,
  /**
   * Internal errors. Means some invariant expected by underlying system has been broken. If you
   * see one of these errors, something is very broken.
   */
  FIRFunctionsErrorCodeInternal = 13,
  /**
   * The service is currently unavailable. This is a most likely a transient condition and may be
   * corrected by retrying with a backoff.
   */
  FIRFunctionsErrorCodeUnavailable = 14,
  /** Unrecoverable data loss or corruption. */
  FIRFunctionsErrorCodeDataLoss = 15,
  /** The request does not have valid authentication credentials for the operation. */
  FIRFunctionsErrorCodeUnauthenticated = 16,
} NS_SWIFT_NAME(FunctionsErrorCode);

NS_ASSUME_NONNULL_END
