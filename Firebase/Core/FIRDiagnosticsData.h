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

NS_ASSUME_NONNULL_BEGIN

/** If present, is a BOOL wrapped in an NSNumber. */
extern NSString *const kFIRCDIsDataCollectionDefaultEnabledKey;

/** If present, is an int32_t wrapped in an NSNumber. */
extern NSString *const kFIRCDConfigurationTypeKey;

/** If present, is an NSString. */
extern NSString *const kFIRCDSdkNameKey;

/** If present, is an NSString. */
extern NSString *const kFIRCDSdkVersionKey;

/** If present, is an int32_t wrapped in an NSNumber. */
extern NSString *const kFIRCDllAppsCountKey;

/** If present, is an NSString. */
extern NSString *const kFIRCDGoogleAppIDKey;

/** If present, is an NSString. */
extern NSString *const kFIRCDBundleIDKey;

/** If present, is a BOOL wrapped in an NSNumber. */
extern NSString *const kFIRCDUsingOptionsFromDefaultPlistKey;

/** If present, is an NSString. */
extern NSString *const kFIRCDLibraryVersionIDKey;

/** If present, is an NSString. */
extern NSString *const kFIRCDFirebaseUserAgentKey;

/** Defines the interface of a data object needed to log diagnostics data. */
@protocol FIRCoreDiagnosticsData <NSObject>

@required

/** A dictionary containing data (non-exhaustive) to be logged in diagnostics. */
@property(nonatomic) NSDictionary<NSString *, id> *diagnosticObjects;

@end

/** Implements the FIRCoreDiagnosticsData protocol to log diagnostics data. */
@interface FIRDiagnosticsData : NSObject <FIRCoreDiagnosticsData>

/** Inserts values into the diagnosticObjects dictionary if the value isn't nil.
 *
 * @param value The value to insert if it's not nil.
 * @param key The key to associate it with.
 */
- (void)insertValue:(nullable id)value forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
