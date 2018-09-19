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

#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>

/**
 * @enum FIRDLLogEvent
 * @abstract Types of events that may be logged to Scion.
 */
typedef NS_ENUM(NSInteger, FIRDLLogEvent) {
  /** Log event where the app is first opened with a DL. */
  FIRDLLogEventFirstOpen,
  /** Log event where the app is subsequently opened with a DL. */
  FIRDLLogEventAppOpen,
};

/**
 * @fn FIRDLLogEventToScion
 * @abstract Logs a given event to Scion
 * @param event The event type that occurred.
 * @param source The utm_source URL parameter value.
 * @param medium The utm_medium URL parameter value.
 * @param campaign The utm_campaign URL parameter value.
 * @param analytics The class to be used as the receiver of the logging method.
 */
void FIRDLLogEventToScion(FIRDLLogEvent event,
                          NSString* _Nullable source,
                          NSString* _Nullable medium,
                          NSString* _Nullable campaign,
                          id<FIRAnalyticsInterop> _Nullable analytics);
