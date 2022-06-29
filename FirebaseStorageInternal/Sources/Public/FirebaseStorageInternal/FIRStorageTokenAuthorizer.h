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

#if SWIFT_PACKAGE
@import GTMSessionFetcherCore;
#else
#import <GTMSessionFetcher/GTMSessionFetcherService.h>
#endif

@protocol FIRAuthInterop;
@protocol FIRAppCheckInterop;

NS_ASSUME_NONNULL_BEGIN

/**
 * Wrapper class for FIRAuthInterop that implements the GTMFetcherAuthorizationProtocol,
 * so as to easily provide GTMSessionFetcher fetches a Firebase Authentication JWT
 * for the current logged in user. Handles token expiration and other failure cases.
 * If no authentication provider exists or no token is found, no token is added
 * and the request is passed.
 */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@interface FIRStorageTokenAuthorizer : NSObject <GTMFetcherAuthorizationProtocol>
#pragma clang diagnostic pop

/**
 * Initializes the token authorizer with an instance of FIRApp.
 * @param googleAppID The Google AppID of the app to send with the request.
 * @param auth An instance that provides access to Auth functionality, if it exists.
 * @param appCheck An instance that provides access to AppCheck functionality, if it exists.
 * @return Returns an instance of FIRStorageTokenAuthorizer which adds the appropriate
 * "Authorization" header to all outbound requests. Note that a token may not be added
 * if the Auth instance is nil. This allows for unauthenticated access, if Firebase
 * Storage rules allow for it.
 */
- (instancetype)initWithGoogleAppID:(NSString *)googleAppID
                     fetcherService:(GTMSessionFetcherService *)service
                       authProvider:(nullable id<FIRAuthInterop>)auth
                           appCheck:(nullable id<FIRAppCheckInterop>)appCheck;

@end

NS_ASSUME_NONNULL_END
