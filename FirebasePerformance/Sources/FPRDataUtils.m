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

#import "FirebasePerformance/Sources/FPRDataUtils.h"

#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/FPRConsoleLogger.h"

#pragma mark - Public functions

NSString *FPRReservableName(NSString *name) {
  NSString *reservableName =
      [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if ([reservableName hasPrefix:kFPRInternalNamePrefix]) {
    FPRLogError(kFPRClientNameReserved, @"%@ prefix is reserved. Dropped %@.",
                kFPRInternalNamePrefix, reservableName);
    return nil;
  }

  if (reservableName.length == 0) {
    FPRLogError(kFPRClientNameLengthCheckFailed, @"Given name is empty.");
    return nil;
  }

  if (reservableName.length > kFPRMaxNameLength) {
    FPRLogError(kFPRClientNameLengthCheckFailed, @"%@ is greater than %d characters, dropping it.",
                reservableName, kFPRMaxNameLength);
    return nil;
  }

  return reservableName;
}

NSString *FPRReservableAttributeName(NSString *name) {
  NSString *reservableName =
      [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

  static NSArray<NSString *> *reservedPrefix = nil;
  static NSPredicate *characterCheck = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    reservedPrefix = @[ @"firebase_", @"google_", @"ga_" ];
    NSString *characterRegex = @"[A-Z0-9a-z_]*";
    characterCheck = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", characterRegex];
  });

  __block BOOL containsReservedPrefix = NO;
  [reservedPrefix enumerateObjectsUsingBlock:^(NSString *prefix, NSUInteger idx, BOOL *stop) {
    if ([reservableName hasPrefix:prefix]) {
      FPRLogError(kFPRClientNameReserved, @"%@ prefix is reserved. Dropped %@.", prefix,
                  reservableName);
      *stop = YES;
      containsReservedPrefix = YES;
    }
  }];

  if (containsReservedPrefix) {
    return nil;
  }

  if (reservableName.length == 0) {
    FPRLogError(kFPRClientNameLengthCheckFailed, @"Given name is empty.");
    return nil;
  }

  if ([characterCheck evaluateWithObject:reservableName] == NO) {
    FPRLogError(kFPRAttributeNameIllegalCharacters,
                @"Illegal characters used for attribute name, "
                 "characters allowed are alphanumeric or underscore.");
    return nil;
  }

  if (reservableName.length > kFPRMaxAttributeNameLength) {
    FPRLogError(kFPRClientNameLengthCheckFailed, @"%@ is greater than %d characters, dropping it.",
                reservableName, kFPRMaxAttributeNameLength);
    return nil;
  }

  return reservableName;
}

NSString *FPRValidatedAttributeValue(NSString *value) {
  if (value.length == 0) {
    FPRLogError(kFPRClientNameLengthCheckFailed, @"Given value is empty.");
    return nil;
  }

  if (value.length > kFPRMaxAttributeValueLength) {
    FPRLogError(kFPRClientNameLengthCheckFailed, @"%@ is greater than %d characters, dropping it.",
                value, kFPRMaxAttributeValueLength);
    return nil;
  }

  return value;
}

NSString *FPRTruncatedURLString(NSString *URLString) {
  NSString *truncatedURLString = URLString;
  NSString *pathSeparator = @"/";
  if (truncatedURLString.length > kFPRMaxURLLength) {
    NSString *truncationCharacter =
        [truncatedURLString substringWithRange:NSMakeRange(kFPRMaxURLLength, 1)];

    truncatedURLString = [URLString substringToIndex:kFPRMaxURLLength];
    if (![pathSeparator isEqual:truncationCharacter]) {
      NSRange rangeOfTruncation = [truncatedURLString rangeOfString:pathSeparator
                                                            options:NSBackwardsSearch];
      truncatedURLString = [URLString substringToIndex:rangeOfTruncation.location];
    }

    FPRLogWarning(kFPRClientNameTruncated, @"URL exceeds %d characters. Truncated url: %@",
                  kFPRMaxURLLength, truncatedURLString);
  }
  return truncatedURLString;
}

NSString *FPRValidatedMccMnc(NSString *mcc, NSString *mnc) {
  if ([mcc length] != 3 || [mnc length] < 2 || [mnc length] > 3) return nil;

  static NSCharacterSet *notDigits;
  static dispatch_once_t token;
  dispatch_once(&token, ^{
    notDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
  });
  NSString *mccMnc = [mcc stringByAppendingString:mnc];
  if ([mccMnc rangeOfCharacterFromSet:notDigits].location != NSNotFound) return nil;
  return mccMnc;
}
