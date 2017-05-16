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

typedef NS_ENUM(int8_t, FIRMessagingLogLevel) {
  kFIRMessagingLogLevelDebug,
  kFIRMessagingLogLevelInfo,
  kFIRMessagingLogLevelError,
  kFIRMessagingLogLevelAssert,
};

/**
 *  Config used to set different options in Firebase Messaging.
 */
@interface FIRMessagingConfig : NSObject

/**
 * The log level for the FIRMessaging library. Valid values are `kFIRMessagingLogLevelDebug`,
 *   `kFIRMessagingLogLevelInfo`, `kFIRMessagingLogLevelError`, and `kFIRMessagingLogLevelAssert`.
 */
@property(nonatomic, readwrite, assign) FIRMessagingLogLevel logLevel;

/**
 *  Get default configuration for FIRMessaging. The default config has logLevel set to
 *  `kFIRMessagingLogLevelError` and `receiverDelegate` is set to nil.
 *
 *  @return FIRMessagingConfig sharedInstance.
 */
+ (instancetype)defaultConfig;

@end

