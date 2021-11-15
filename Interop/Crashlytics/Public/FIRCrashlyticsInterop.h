/*
 * Copyright 2021 Google
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

@protocol FIRCrashlyticsInterop

NS_ASSUME_NONNULL_BEGIN

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
 * Sets a custom key and value to be associated with subsequent fatal and non-fatal reports.
 * When setting an object value, the object is converted to a string. This is
 * typically done by calling "-[NSObject description]".
 *
 * @param value The value to be associated with the key
 * @param key A unique key
 */
- (void)setCustomValue:(id)value forKey:(NSString *)key;

/**
 * Records a non-fatal event described by an NSError object. The events are
 * grouped and displayed similarly to crashes. Keep in mind that this method can be expensive.
 * The total number of NSErrors that can be recorded during your app's life-cycle is limited by a
 * fixed-size circular buffer. If the buffer is overrun, the oldest data is dropped. Errors are
 * relayed to Crashlytics on a subsequent launch of your application.
 *
 * @param error Non-fatal error to be recorded
 */
- (void)recordError:(NSError *)error NS_SWIFT_NAME(record(error:));

@end

NS_ASSUME_NONNULL_END
