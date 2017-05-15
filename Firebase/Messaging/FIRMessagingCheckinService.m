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

#import "FIRMessagingCheckinService.h"

#import "FIRMessagingUtilities.h"
#import "NSError+FIRMessaging.h"

@interface FIRMessagingCheckinService ()

// This property is of type FIRInstanceIDCheckinPreferences, if InstanceID was directly linkable
@property(nonatomic, readwrite, strong) id checkinPreferences;

@end

@implementation FIRMessagingCheckinService;

#pragma mark - Reflection-Based Getter Functions

// Encapsulates the -hasValidCheckinInfo method of FIRInstanceIDCheckinPreferences
BOOL FIRMessagingCheckinService_hasValidCheckinInfo(id checkinPreferences) {
  SEL hasValidCheckinInfoSelector = NSSelectorFromString(@"hasValidCheckinInfo");
  if (![checkinPreferences respondsToSelector:hasValidCheckinInfoSelector]) {
    // Can't check hasValidCheckinInfo
    return NO;
  }

  // Since hasValidCheckinInfo returns a BOOL, use NSInvocation
  NSMethodSignature *methodSignature =
      [[checkinPreferences class] instanceMethodSignatureForSelector:hasValidCheckinInfoSelector];
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
  invocation.selector = hasValidCheckinInfoSelector;
  invocation.target = checkinPreferences;
  [invocation invoke];
  BOOL returnValue;
  [invocation getReturnValue:&returnValue];
  return returnValue;
}

// Returns a non-scalar (id) object based on the property name
id FIRMessagingCheckinService_propertyNamed(id checkinPreferences, NSString *propertyName) {
  SEL propertyGetterSelector = NSSelectorFromString(propertyName);
  if ([checkinPreferences respondsToSelector:propertyGetterSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [checkinPreferences performSelector:propertyGetterSelector];
#pragma clang diagnostic pop
  }
  return nil;
}

#pragma mark - Methods

- (BOOL)tryToLoadPrefetchedCheckinPreferences {
  Class instanceIDClass = NSClassFromString(@"FIRInstanceID");
  if (!instanceIDClass) {
    // InstanceID is not linked
    return NO;
  }

  // [FIRInstanceID instanceID]
  SEL instanceIDSelector = NSSelectorFromString(@"instanceID");
  if (![instanceIDClass respondsToSelector:instanceIDSelector]) {
    return NO;
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  id instanceID = [instanceIDClass performSelector:instanceIDSelector];
#pragma clang diagnostic pop
  if (!instanceID) {
    // Instance ID singleton not available
    return NO;
  }

  // [[FIRInstanceID instanceID] cachedCheckinPreferences]
  SEL cachedCheckinPrefsSelector = NSSelectorFromString(@"cachedCheckinPreferences");
  if (![instanceID respondsToSelector:cachedCheckinPrefsSelector]) {
    // cachedCheckinPreferences is not accessible
    return NO;
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  id checkinPreferences = [instanceID performSelector:cachedCheckinPrefsSelector];
#pragma clang diagnostic pop
  if (!checkinPreferences) {
    // No cached checkin prefs
    return NO;
  }

  BOOL hasValidInfo = FIRMessagingCheckinService_hasValidCheckinInfo(checkinPreferences);
  if (hasValidInfo) {
    self.checkinPreferences = checkinPreferences;
  }
  return hasValidInfo;
}

#pragma mark - API

- (NSString *)deviceAuthID {
  return FIRMessagingCheckinService_propertyNamed(self.checkinPreferences, @"deviceID");
}

- (NSString *)secretToken {
  return FIRMessagingCheckinService_propertyNamed(self.checkinPreferences, @"secretToken");
}

- (NSString *)versionInfo {
  return FIRMessagingCheckinService_propertyNamed(self.checkinPreferences, @"versionInfo");
}

- (NSString *)digest {
  return FIRMessagingCheckinService_propertyNamed(self.checkinPreferences, @"digest");
}

- (BOOL)hasValidCheckinInfo {
  return FIRMessagingCheckinService_hasValidCheckinInfo(self.checkinPreferences);
}

@end
