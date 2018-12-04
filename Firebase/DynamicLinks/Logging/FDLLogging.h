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

#import <Foundation/Foundation.h>

/** Log level for FIRLogger. */
typedef NS_ENUM(NSInteger, FDLLogLevel) {
  FDLLogLevelError = 0,
  FDLLogLevelWarning,
  FDLLogLevelNotice,
  FDLLogLevelInfo,
  FDLLogLevelDebug,
};

/**
 Used to specify a unique integer for FIRLogger. Add entries ONLY to the end of the enum.
 Unique values are specified so that items can be safely removed without affecting the others.
 */
typedef NS_ENUM(NSInteger, FDLLogIdentifier) {
  FDLLogIdentifierSetupNilAPIKey = 0,
  FDLLogIdentifierSetupNilClientID = 1,
  FDLLogIdentifierSetupNonDefaultApp = 2,
  FDLLogIdentifierSetupInvalidDomainURIPrefixScheme = 3,
  FDLLogIdentifierSetupInvalidDomainURIPrefix = 4,
  FDLLogIdentifierSetupWarnHTTPSScheme = 5,
};

/** The appropriate formatter for using NSInteger in FIRLogger. */
FOUNDATION_EXPORT NSString *const FDLMessageCodeIntegerFormat;

/** Logs a message with FIRLogger. */
FOUNDATION_EXPORT void FDLLog(FDLLogLevel logLevel,
                              FDLLogIdentifier identifer,
                              NSString *message,
                              ...) NS_FORMAT_FUNCTION(3, 4);
