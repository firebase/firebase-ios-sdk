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

// Set this to 1 to have the library print out as much as possible about what GDT is doing.
#define GDT_VERBOSE_LOGGING 0

/** A list of message codes to print in the logger that help to correspond printed messages with
 * code locations.
 *
 * Prefixes:
 * - MCW => MessageCodeWarning
 * - MCE => MessageCodeError
 */
typedef NS_ENUM(NSInteger, GDTCORMessageCode) {

  /** For warning messages concerning transportBytes: not being implemented by a data object. */
  GDTCORMCWDataObjectMissingBytesImpl = 1,

  /** For warning messages concerning a failed event upload. */
  GDTCORMCWUploadFailed = 2,

  /** For warning messages concerning a forced event upload. */
  GDTCORMCWForcedUpload = 3,

  /** For warning messages concerning a failed reachability call. */
  GDTCORMCWReachabilityFailed = 4,

  /** For error messages concerning transform: not being implemented by an event transformer. */
  GDTCORMCETransformerDoesntImplementTransform = 1000,

  /** For error messages concerning the creation of a directory failing. */
  GDTCORMCEDirectoryCreationError = 1001,

  /** For error messages concerning the writing of a event file. */
  GDTCORMCEFileWriteError = 1002,

  /** For error messages concerning the lack of a prioritizer for a given backend. */
  GDTCORMCEPrioritizerError = 1003,

  /** For error messages concerning a package delivery API violation. */
  GDTCORMCEDeliverTwice = 1004,

  /** For error messages concerning an error in an implementation of -transportBytes. */
  GDTCORMCETransportBytesError = 1005,

  /** For general purpose error messages in a dependency. */
  GDTCORMCEGeneralError = 1006,

  /** For fatal errors. Please go to https://github.com/firebase/firebase-ios-sdk/issues and open
   * an issue if you encounter an error with this code.
   */
  GDTCORMCEFatalAssertion = 1007,

  /** For error messages concerning the reading of a event file. */
  GDTCORMCEFileReadError = 1008
};

/** Prints the given code and format string to the console.
 *
 * @param code The message code describing the nature of the log.
 * @param format The format string.
 */
FOUNDATION_EXPORT
void GDTCORLog(GDTCORMessageCode code, NSString *_Nonnull format, ...) NS_FORMAT_FUNCTION(2, 3);

/** Prints an assert log to the console.
 *
 * @param wasFatal Send YES if the assertion should be fatal, NO otherwise.
 * @param file The file in which the failure occurred.
 * @param line The line number of the failure.
 * @param format The format string.
 */
FOUNDATION_EXPORT void GDTCORLogAssert(BOOL wasFatal,
                                       NSString *_Nonnull file,
                                       NSInteger line,
                                       NSString *_Nullable format,
                                       ...) NS_FORMAT_FUNCTION(4, 5);

/** Returns the string that represents some message code.
 *
 * @param code The code to convert to a string.
 * @return The string representing the message code.
 */
FOUNDATION_EXPORT NSString *_Nonnull GDTCORMessageCodeEnumToString(GDTCORMessageCode code);

// A define to wrap GULLogWarning with slightly more convenient usage.
#define GDTCORLogWarning(MESSAGE_CODE, MESSAGE_FORMAT, ...) \
  GDTCORLog(MESSAGE_CODE, MESSAGE_FORMAT, __VA_ARGS__);

// A define to wrap GULLogError with slightly more convenient usage and a failing assert.
#define GDTCORLogError(MESSAGE_CODE, MESSAGE_FORMAT, ...) \
  GDTCORLog(MESSAGE_CODE, MESSAGE_FORMAT, __VA_ARGS__);

// A define to wrap NSLog for verbose console logs only useful for local debugging.
#if GDT_VERBOSE_LOGGING == 1
#define GDTCORLogDebug(FORMAT, ...) NSLog(@"GDT: " FORMAT, __VA_ARGS__);
#else
#define GDTCORLogDebug(...)
#endif  // GDT_VERBOSE_LOGGING == 1
