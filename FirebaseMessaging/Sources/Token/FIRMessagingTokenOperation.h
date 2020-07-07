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

#import <Foundation/Foundation.h>

@class FIRMessagingCheckinPreferences;

NS_ASSUME_NONNULL_BEGIN

/**
 *  Represents the action taken on an FCM token.
 */
typedef NS_ENUM(NSInteger, FIRMessagingTokenAction) {
  FIRMessagingTokenActionFetch,
  FIRMessagingTokenActionDeleteToken,
  FIRMessagingTokenActionDeleteTokenAndIID,
};

/**
 * Represents the possible results of a token operation.
 */
typedef NS_ENUM(NSInteger, FIRMessagingTokenOperationResult) {
  FIRMessagingTokenOperationSucceeded,
  FIRMessagingTokenOperationError,
  FIRMessagingTokenOperationCancelled,
};

/**
 *  Callback to invoke once the HTTP call to FIRMessaging backend for updating
 *  subscription finishes.
 *
 *  @param result  The result of the operation.
 *  @param token   If the action for fetching a token and the request was successful, this will hold
 *                 the value of the token. Otherwise nil.
 *  @param error   The error which occurred while performing the token operation. This will be nil
 *                 in case the operation was successful, or if the operation was cancelled.
 */
typedef void (^FIRMessagingTokenOperationCompletion)(FIRMessagingTokenOperationResult result,
                                                     NSString *_Nullable token,
                                                     NSError *_Nullable error);

@interface FIRMessagingTokenOperation : NSOperation

@property(nonatomic, readonly) FIRMessagingTokenAction action;
@property(nonatomic, readonly, nullable) NSString *authorizedEntity;
@property(nonatomic, readonly, nullable) NSString *scope;
@property(nonatomic, readonly, nullable) NSDictionary<NSString *, NSString *> *options;
@property(nonatomic, readonly, strong) FIRMessagingCheckinPreferences *checkinPreferences;
@property(nonatomic, readonly, strong) NSString *instanceID;

@property(nonatomic, readonly) FIRMessagingTokenOperationResult result;

@property(atomic, strong, nullable) NSURLSessionDataTask *dataTask;

#pragma mark - Request Construction
+ (NSMutableArray<NSURLQueryItem *> *)standardQueryItemsWithDeviceID:(NSString *)deviceID
                                                               scope:(NSString *)scope;
- (NSMutableURLRequest *)tokenRequest;
- (instancetype)init NS_UNAVAILABLE;

#pragma mark - Initialization
- (instancetype)initWithAction:(FIRMessagingTokenAction)action
           forAuthorizedEntity:(nullable NSString *)authorizedEntity
                         scope:(NSString *)scope
                       options:(nullable NSDictionary<NSString *, NSString *> *)options
            checkinPreferences:(FIRMessagingCheckinPreferences *)checkinPreferences
                    instanceID:(NSString *)instanceID;

- (void)addCompletionHandler:(FIRMessagingTokenOperationCompletion)handler;

#pragma mark - Result
- (void)finishWithResult:(FIRMessagingTokenOperationResult)result
                   token:(nullable NSString *)token
                   error:(nullable NSError *)error;
@end

NS_ASSUME_NONNULL_END
