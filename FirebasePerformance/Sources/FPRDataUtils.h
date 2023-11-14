// Copyright 2020 Google LLC
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

/** Trims the given name string and checks if the name is reservable.
 *
 *  @param name The name to be checked for reservability.
 *  @return Reservable name or nil if there is an error.
 */
FOUNDATION_EXTERN NSString *FPRReservableName(NSString *name);

/** Trims the given name string and checks if the name is reservable.
 *
 *  @param name The name to be checked for reservability for an attribute name.
 *  @return Reservable name or nil if there is an error.
 */
FOUNDATION_EXTERN NSString *FPRReservableAttributeName(NSString *name);

/** Checks if the given attribute value follows length restrictions.
 *
 *  @param value The value to be checked.
 *  @return Valid value or nil if that does not adhere to length restrictions.
 */
FOUNDATION_EXTERN NSString *FPRValidatedAttributeValue(NSString *value);

/** Truncates the URL string if the length of the URL going beyond the defined limit. The truncation
 *  will happen upto the end of a complete query sub path whose length is less than limit.
 *  For example: If the URL is abc.com/one/two/three/four and if the URL max length is 20, trimmed
 *  URL will be to abc.com/one/two and not abc.com/one/two/thre (three is incomplete).
 *  If the domain name goes beyond 2000 characters (which is unlikely), that might result in an
 *  empty string being returned.
 *
 *  @param URLString A URL string.
 *  @return The unchanged url string or a truncated version if the length goes beyond the limit.
 */
FOUNDATION_EXTERN NSString *FPRTruncatedURLString(NSString *URLString);
