// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The Firebase Crashlytics Report provides a way to read and write information
 * to a past Crashlytics reports. A common use case is gathering end-user feedback
 * on the next run of the app.
 *
 * The CrashlyticsReport should be modified before calling send/deleteUnsentReports.
 */
NS_SWIFT_NAME(CrashlyticsReport)
@interface FIRCrashlyticsReport : NSObject

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Returns the unique ID for the Crashlytics report.
 */
@property(nonatomic, readonly) NSString *reportID;

/**
 * Returns the date that the report was created.
 */
@property(nonatomic, readonly) NSDate *dateCreated;

/**
 * Returns true when one of the events in the Crashlytics report is a crash.
 */
@property(nonatomic, readonly) BOOL hasCrash;

/**
 * Adds logging that is sent with your crash data. The logging does not appear  in the
 * system.log and is only visible in the Crashlytics dashboard.
 *
 * @param msg Message to log
 */
- (void)log:(NSString *)msg;

/**
 * Adds logging that is sent with your crash data. The logging does not appear  in the
 * system.log and is only visible in the Crashlytics dashboard.
 *
 * @param format Format of string
 * @param ... A comma-separated list of arguments to substitute into format
 */
- (void)logWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

/**
 * Adds logging that is sent with your crash data. The logging does not appear  in the
 * system.log and is only visible in the Crashlytics dashboard.
 *
 * @param format Format of string
 * @param args Arguments to substitute into format
 */
- (void)logWithFormat:(NSString *)format
            arguments:(va_list)args NS_SWIFT_NAME(log(format:arguments:));

/**
 * Sets a custom key and value to be associated with subsequent fatal and non-fatal reports.
 * When setting an object value, the object is converted to a string. This is
 * typically done by using the object's description.
 *
 * @param value The value to be associated with the key
 * @param key A unique key
 */
- (void)setCustomValue:(nullable id)value forKey:(NSString *)key;

/**
 * Sets custom keys and values to be associated with subsequent fatal and non-fatal reports.
 * The objects in the dictionary are converted to strings. This is
 * typically done by using the object's description.
 *
 * @param keysAndValues The values to be associated with the corresponding keys
 */
- (void)setCustomKeysAndValues:(NSDictionary *)keysAndValues;

/**
 * Records a user ID (identifier) that's associated with subsequent fatal and non-fatal reports.
 *
 * If you want to associate a crash with a specific user, we recommend specifying an arbitrary
 * string (e.g., a database, ID, hash, or other value that you can index and query, but is
 * meaningless to a third-party observer). This allows you to facilitate responses for support
 * requests and reach out to users for more information.
 *
 * @param userID An arbitrary user identifier string that associates a user to a record in your
 * system.
 */
- (void)setUserID:(nullable NSString *)userID;

@end

NS_ASSUME_NONNULL_END
