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

#import <Foundation/Foundation.h>
#import "FirebaseInAppMessaging/Sources/Private/Analytics/FIRIAMClientInfoFetcher.h"
#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMFetchResponseParser.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMServerMsgFetchStorage.h"
#import "FirebaseInAppMessaging/Sources/Private/Runtime/FIRIAMFetchFlow.h"
#import "FirebaseInAppMessaging/Sources/Private/Runtime/FIRIAMSDKSettings.h"

NS_ASSUME_NONNULL_BEGIN

// implementation of FIRIAMMessageFetcher by making Restful API requests to firebase
// in-app messaging services
@interface FIRIAMMsgFetcherUsingRestful : NSObject <FIRIAMMessageFetcher>
/**
 * Create an instance which uses NSURLSession to make the restful api call.
 *
 * @param serverHost API server host.
 * @param fbProjectNumber project number used for the API call. It's the GCM_SENDER_ID
 *                         field in GoogleService-Info.plist.
 * @param fbAppId It's the GOOGLE_APP_ID field in GoogleService-Info.plist.
 * @param apiKey API key.
 * @param fetchStorage used to persist the fetched response.
 * @param clientInfoFetcher used to fetch iid info for the current app.
 * @param URLSession can be nil in which case the class would create NSURLSession
 *                   internally to perform the network request. Having it here so that
 *                   it's easier for doing mocking with unit testing.
 */
- (instancetype)initWithHost:(NSString *)serverHost
                HTTPProtocol:(NSString *)HTTPProtocol
                     project:(NSString *)fbProjectNumber
                 firebaseApp:(NSString *)fbAppId
                      APIKey:(NSString *)apiKey
                fetchStorage:(FIRIAMServerMsgFetchStorage *)fetchStorage
           instanceIDFetcher:(FIRIAMClientInfoFetcher *)clientInfoFetcher
             usingURLSession:(nullable NSURLSession *)URLSession
              responseParser:(FIRIAMFetchResponseParser *)responseParser;

@end

NS_ASSUME_NONNULL_END
