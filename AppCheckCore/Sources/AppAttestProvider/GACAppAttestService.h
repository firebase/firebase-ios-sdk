/*
 * Copyright 2021 Google LLC
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

@class FBLPromise<ValueType>;

NS_ASSUME_NONNULL_BEGIN

/// See `DCAppAttestService`
/// https://developer.apple.com/documentation/devicecheck/dcappattestservice?language=objc
@protocol GACAppAttestService <NSObject>

@property(getter=isSupported, readonly) BOOL supported;

- (void)generateKeyWithCompletionHandler:(void (^)(NSString *keyId,
                                                   NSError *error))completionHandler;

- (void)attestKey:(NSString *)keyId
       clientDataHash:(NSData *)clientDataHash
    completionHandler:(void (^)(NSData *attestationObject, NSError *error))completionHandler;

- (void)generateAssertion:(NSString *)keyId
           clientDataHash:(NSData *)clientDataHash
        completionHandler:(void (^)(NSData *assertionObject, NSError *error))completionHandler;

@end

NS_ASSUME_NONNULL_END
