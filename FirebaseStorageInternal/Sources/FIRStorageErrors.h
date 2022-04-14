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

#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageConstants.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRIMPLStorageReference;

/**
 * Adds wrappers for common Firebase Storage errors (including creating errors from GCS errors).
 * For more information on unwrapping GCS errors, see the GCS errors docs:
 * https://cloud.google.com/storage/docs/json_api/v1/status-codes
 * This is never publicly exposed to end developers (as they will simply see an NSError).
 */
@interface FIRStorageErrors : NSObject

/**
 * Creates a Firebase Storage error from a specific FIRStorageErrorCode.
 */
+ (NSError *)errorWithCode:(FIRIMPLStorageErrorCode)code;

/**
 * Creates a Firebase Storage error from a specific FIRStorageErrorCode while adding
 * custom info from an optionally provided info dictionary.
 */
+ (NSError *)errorWithCode:(FIRIMPLStorageErrorCode)code
            infoDictionary:(nullable NSDictionary *)dictionary;

/**
 * Creates a Firebase Storage error from a specific GCS error and FIRIMPLStorageReference.
 * @param error Server error to wrap and return as a Firebase Storage error.
 * @param reference FIRIMPLStorageReference which provides context about the request being made.
 * @return Returns a Firebase Storage error, or nil if no error is provided.
 */
+ (nullable NSError *)errorWithServerError:(nullable NSError *)error
                                 reference:(nullable FIRIMPLStorageReference *)reference;

/**
 * Creates a Firebase Storage error from an invalid request.
 *
 * @param request The NSData representation of the invalid user request.
 * @return Returns the corresponding Firebase Storage error.
 */
+ (NSError *)errorWithInvalidRequest:(NSData *)request;

/**
 * Creates a Firebase Storage error with a custom error message.
 *
 * @param errorMessage A custom error message.
 * @return Returns the corresponding Firebase Storage error.
 */
+ (NSError *)errorWithCustomMessage:(NSString *)errorMessage;

@end

FOUNDATION_EXPORT NSString *const FIRStorageErrorDomainInternal;

NS_ASSUME_NONNULL_END
