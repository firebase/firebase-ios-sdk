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

/**
 * A `FIRHTTPSCallableResult` contains the result of calling a `FIRHTTPSCallable`.
 */
NS_SWIFT_NAME(HTTPSCallableResult)
@interface FIRHTTPSCallableResult : NSObject

- (id)init NS_UNAVAILABLE;

/**
 * The data that was returned from the Callable HTTPS trigger.
 *
 * The data is in the form of native objects. For example, if your trigger returned an
 * array, this object would be an NSArray. If your trigger returned a JavaScript object with
 * keys and values, this object would be an NSDictionary.
 */
@property(nonatomic, strong, readonly) id data;

@end

/**
 * A `FIRHTTPSCallable` is reference to a particular Callable HTTPS trigger in Cloud Functions.
 */
NS_SWIFT_NAME(HTTPSCallable)
@interface FIRHTTPSCallable : NSObject

- (id)init NS_UNAVAILABLE;

/**
 * Executes this Callable HTTPS trigger asynchronously without any parameters.
 *
 * The request to the Cloud Functions backend made by this method automatically includes a
 * Firebase Instance ID token to identify the app instance. If a user is logged in with Firebase
 * Auth, an auth ID token for the user is also automatically included.
 *
 * Firebase Instance ID sends data to the Firebase backend periodically to collect information
 * regarding the app instance. To stop this, see `[FIRInstanceID deleteIDWithHandler:]`. It
 * resumes with a new Instance ID the next time you call this method.
 *
 * @param completion The block to call when the HTTPS request has completed.
 */
- (void)callWithCompletion:
    (void (^)(FIRHTTPSCallableResult *_Nullable result, NSError *_Nullable error))completion
    NS_SWIFT_NAME(call(completion:));

/**
 * Executes this Callable HTTPS trigger asynchronously.
 *
 * The data passed into the trigger can be any of the following types:
 * * NSNull
 * * NSString
 * * NSNumber
 * * NSArray<id>, where the contained objects are also one of these types.
 * * NSDictionary<NSString, id>, where the values are also one of these types.
 *
 * The request to the Cloud Functions backend made by this method automatically includes a
 * Firebase Instance ID token to identify the app instance. If a user is logged in with Firebase
 * Auth, an auth ID token for the user is also automatically included.
 *
 * Firebase Instance ID sends data to the Firebase backend periodically to collect information
 * regarding the app instance. To stop this, see `[FIRInstanceID deleteIDWithHandler:]`. It
 * resumes with a new Instance ID the next time you call this method.
 *
 * @param data Parameters to pass to the trigger.
 * @param completion The block to call when the HTTPS request has completed.
 */
// clang-format off
// because it incorrectly breaks this NS_SWIFT_NAME.
- (void)callWithObject:(nullable id)data
            completion:(void (^)(FIRHTTPSCallableResult *_Nullable result,
                                 NSError *_Nullable error))completion
    NS_SWIFT_NAME(call(_:completion:));
// clang-format on

/**
 * The timeout to use when calling the function. Defaults to 60 seconds.
 */
@property(nonatomic, assign) NSTimeInterval timeoutInterval;

@end

NS_ASSUME_NONNULL_END
