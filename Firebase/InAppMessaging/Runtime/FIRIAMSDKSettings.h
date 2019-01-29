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

@class FIRIAMClearcutStrategy;

NS_ASSUME_NONNULL_BEGIN
@interface FIRIAMSDKSettings : NSObject
// settings related to communicating with in-app messaging server
@property(nonatomic, copy) NSString *firebaseProjectNumber;
@property(nonatomic, copy) NSString *firebaseAppId;
@property(nonatomic, copy) NSString *apiKey;
@property(nonatomic, copy) NSString *apiServerHost;
@property(nonatomic, copy) NSString *apiHttpProtocol;  // http or https. It should be always
                                                       // https on production. Allow http to
                                                       // faciliate testing in non-prod environment
@property(nonatomic) NSTimeInterval fetchMinIntervalInMinutes;

// settings related to activity logger
@property(nonatomic) NSInteger loggerMaxCountBeforeReduce;
@property(nonatomic) NSInteger loggerSizeAfterReduce;
@property(nonatomic) BOOL loggerInVerboseMode;

// settings for controlling rendering frequency for messages rendered from app foreground triggers
@property(nonatomic) NSTimeInterval appFGRenderMinIntervalInMinutes;

// host name for clearcut servers
@property(nonatomic, copy) NSString *clearcutServerHost;
// clearcut strategy
@property(nonatomic, strong) FIRIAMClearcutStrategy *clearcutStrategy;

// The global flag at whole Firebase level for automatic data collection. On FIAM SDK startup,
// it would be retreived from FIRApp's corresponding setting.
@property(nonatomic, getter=isFirebaseAutoDataCollectionEnabled)
    BOOL firebaseAutoDataCollectionEnabled;

- (NSString *)description;
@end
NS_ASSUME_NONNULL_END
