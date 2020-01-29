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

#import "DynamicLinks/FIRDLRetrievalProcessFactory.h"

#import "DynamicLinks/FIRDLDefaultRetrievalProcessV2.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRDLRetrievalProcessFactory {
  FIRDynamicLinkNetworking *_networkingService;
  NSString *_clientID;
  NSString *_URLScheme;
  NSString *_APIKey;
  NSString *_FDLSDKVersion;
  id<FIRDLRetrievalProcessDelegate> _delegate;
}

- (instancetype)initWithNetworkingService:(FIRDynamicLinkNetworking *)networkingService
                                 clientID:(NSString *)clientID
                                URLScheme:(NSString *)URLScheme
                                   APIKey:(NSString *)APIKey
                            FDLSDKVersion:(NSString *)FDLSDKVersion
                                 delegate:(id<FIRDLRetrievalProcessDelegate>)delegate {
  if (self = [super init]) {
    _networkingService = networkingService;
    _clientID = clientID;
    _URLScheme = URLScheme;
    _APIKey = APIKey;
    _FDLSDKVersion = FDLSDKVersion;
    _delegate = delegate;
  }
  return self;
}

- (id<FIRDLRetrievalProcessProtocol>)automaticRetrievalProcess {
  return [[FIRDLDefaultRetrievalProcessV2 alloc] initWithNetworkingService:_networkingService
                                                                  clientID:_clientID
                                                                 URLScheme:_URLScheme
                                                                    APIKey:_APIKey
                                                             FDLSDKVersion:_FDLSDKVersion
                                                                  delegate:_delegate];
}

@end

NS_ASSUME_NONNULL_END
