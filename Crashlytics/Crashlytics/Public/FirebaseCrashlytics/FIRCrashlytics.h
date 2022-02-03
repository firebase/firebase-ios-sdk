// Copyright 2019 Google
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

#import "FIRCrashlyticsReport.h"
#import "FIRExceptionModel.h"

#if __has_include(<Crashlytics/Crashlytics.h>)
#warning "FirebaseCrashlytics and Crashlytics are not compatible \
in the same app because including multiple crash reporters can \
cause problems when registering exception handlers."
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * The Firebase Crashlytics API provides methods to annotate and manage fatal and
 * non-fatal reports captured and reported to Firebase Crashlytics.
 *
 * By default, Firebase Crashlytics is initialized with FirebaseApp.configure().
 *
 * Note: The Crashlytics class cannot be subclassed. If this makes testing difficult,
 * we suggest using a wrapper class or a protocol extension.
 */
NS_SWIFT_NAME(Crashlytics)
@interface FIRCrashlytics : NSObject

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Accesses the singleton Crashlytics instance.
 *
 * @return The singleton Crashlytics instance.
 */
+ (instancetype)crashlytics NS_SWIFT_NAME(crashlytics());

/**
 * Adds logging that is sent with your crash data. The logging does not appear in the
 * system.log and is only visible in the Crashlytics dashboard.
 *
 * @param msg Message to log
 */
- (void)log:(NSString *)msg;

/**
 * Adds logging that is sent with your crash data. The logging does not appear in the
 * system.log and is only visible in the Crashlytics dashboard.
 *
 * @param format Format of string
 * @param ... A comma-separated list of arguments to substitute into format
 */
- (void)logWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

/**
 * Adds logging that is sent with your crash data. The logging does not appear in the
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
 * typically done by using the object's `description`.
 *
 * @param value The value to be associated with the key
 * @param key A unique key
 */
- (void)setCustomValue:(nullable id)value forKey:(NSString *)key;

/**
 * Sets custom keys and values to be associated with subsequent fatal and non-fatal reports.
 * The objects in the dictionary are converted to strings. This is
 * typically done by using the object's  `description`.
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

/**
 * Records a non-fatal event described by an Error object. The events are
 * grouped and displayed similarly to crashes. Keep in mind that this method can be expensive.
 * The total number of Errors that can be recorded during your app's life-cycle is limited by a
 * fixed-size circular buffer. If the buffer is overrun, the oldest data is dropped. Errors are
 * relayed to Crashlytics on a subsequent launch of your application.
 *
 * @param error Non-fatal error to be recorded
 */
- (void)recordError:(NSError *)error NS_SWIFT_NAME(record(error:));

/**
 * Records an Exception Model described by an ExceptionModel object. The events are
 * grouped and displayed similarly to crashes. Keep in mind that this method can be expensive.
 * The total number of ExceptionModels that can be recorded during your app's life-cycle is
 * limited by a fixed-size circular buffer. If the buffer is overrun, the oldest data is dropped.
 * ExceptionModels are relayed to Crashlytics on a subsequent launch of your application.
 *
 * @param exceptionModel Instance of the ExceptionModel to be recorded
 */
- (void)recordExceptionModel:(FIRExceptionModel *)exceptionModel
    NS_SWIFT_NAME(record(exceptionModel:));

/**
 * Returns whether the app crashed during the previous execution.
 */
- (BOOL)didCrashDuringPreviousExecution;

/**
 * Enables/disables automatic data collection.
 *
 * Calling this method overrides both the FirebaseCrashlyticsCollectionEnabled flag in your
 * App's Info.plist and FirebaseApp's isDataCollectionDefaultEnabled flag.
 *
 * When you set a value for this method, it persists across runs of the app.
 *
 * The value does not apply until the next run of the app. If you want to disable data
 * collection without rebooting, add the FirebaseCrashlyticsCollectionEnabled flag to your app's
 * Info.plist.
 * *
 * @param enabled Determines whether automatic data collection is enabled
 */
- (void)setCrashlyticsCollectionEnabled:(BOOL)enabled;

/**
 * Indicates whether or not automatic data collection is enabled
 *
 * This method uses three ways to decide whether automatic data collection is enabled,
 * in order of priority:
 *  - If setCrashlyticsCollectionEnabled is called with a value, use it
 *  - If the FirebaseCrashlyticsCollectionEnabled key is in your app's Info.plist, use it
 *  - Otherwise, use the default isDataCollectionDefaultEnabled in FirebaseApp
 */
- (BOOL)isCrashlyticsCollectionEnabled;

/**
 * Determines whether there are any unsent crash reports cached on the device, then calls the given
 * callback.
 *
 * The callback only executes if automatic data collection is disabled. You can use
 * the callback to get one-time consent from a user upon a crash, and then call
 * sendUnsentReports or deleteUnsentReports, depending on whether or not the user gives consent.
 *
 * Disable automatic collection by:
 *  - Adding the FirebaseCrashlyticsCollectionEnabled: NO key to your App's Info.plist
 *  - Calling `FirebaseCrashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)` in your app
 *  - Setting FirebaseApp's isDataCollectionDefaultEnabled to false
 *
 * @param completion The callback that's executed once Crashlytics finishes checking for unsent
 * reports. The callback is set to true if there are unsent reports on disk.
 */
- (void)checkForUnsentReportsWithCompletion:(void (^)(BOOL))completion
    NS_SWIFT_NAME(checkForUnsentReports(completion:));

/**
 * Determines whether there are any unsent crash reports cached on the device, then calls the given
 * callback with a CrashlyticsReport object that you can use to update the unsent report.
 * CrashlyticsReports have a lot of the familiar Crashlytics methods like setting custom keys and
 * logs.
 *
 * The callback only executes if automatic data collection is disabled. You can use
 * the callback to get one-time consent from a user upon a crash, and then call
 * sendUnsentReports or deleteUnsentReports, depending on whether or not the user gives consent.
 *
 * Disable automatic collection by:
 *  - Adding the FirebaseCrashlyticsCollectionEnabled: NO key to your App's Info.plist
 *  - Calling `FirebaseCrashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)` in your app
 *  - Setting FirebaseApp's isDataCollectionDefaultEnabled to false
 *
 * Not calling send/deleteUnsentReports will result in the report staying on disk, which means the
 * same CrashlyticsReport can show up in multiple runs of the app. If you want avoid duplicates,
 * ensure there was a crash on the last run of the app by checking the value of
 * didCrashDuringPreviousExecution.
 *
 * @param completion The callback that's executed once Crashlytics finishes checking for unsent
 * reports. The callback is called with the newest unsent Crashlytics Report, or nil if there are
 * none cached on disk.
 */
- (void)checkAndUpdateUnsentReportsWithCompletion:
    (void (^)(FIRCrashlyticsReport *_Nullable))completion
    NS_SWIFT_NAME(checkAndUpdateUnsentReports(completion:));

/**
 * Enqueues any unsent reports on the device to upload to Crashlytics.
 *
 * This method only applies if automatic data collection is disabled.
 *
 * When automatic data collection is enabled, Crashlytics automatically uploads and deletes reports
 * at startup, so this method is ignored.
 */
- (void)sendUnsentReports;

/**
 * Deletes any unsent reports on the device.
 *
 * This method only applies if automatic data collection is disabled.
 */
- (void)deleteUnsentReports;

@end

NS_ASSUME_NONNULL_END
