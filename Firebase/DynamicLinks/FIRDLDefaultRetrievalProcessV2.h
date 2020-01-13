/*
 * Copyright 2018 Google
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

#import "DynamicLinks/FIRDLRetrievalProcessProtocols.h"

#import <Foundation/Foundation.h>

@class FIRDynamicLinkNetworking;

NS_ASSUME_NONNULL_BEGIN

/**
 Class to encapsulate logic related to retrieving pending dynamic link.
 In V2 changed comparing to FIRDLDefaultRetrievalProcess:
 - removed Java Script fingerprint and replaced by passing device parametres directly to endpoint;
 - added device model name to endpoint;
 - added handling of iPhone Apps running in compatibility mode on iPad.
 */
@interface FIRDLDefaultRetrievalProcessV2 : NSObject <FIRDLRetrievalProcessProtocol>

- (instancetype)initWithNetworkingService:(FIRDynamicLinkNetworking *)networkingService
                                 clientID:(NSString *)clientID
                                URLScheme:(NSString *)URLScheme
                                   APIKey:(NSString *)APIKey
                            FDLSDKVersion:(NSString *)FDLSDKVersion
                                 delegate:(id<FIRDLRetrievalProcessDelegate>)delegate
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
