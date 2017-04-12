/** @file FIRAuthFakeBackendEmailValidator.m
    @brief Firebase Auth SDK
    @copyright Copyright 2015 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import "googlemac/iPhone/Identity/Firebear/Testing/Source/FIRAuthFakeBackendEmailValidator.h"

// Stolen from:
// https://cs.corp.google.com/codesearch/f/piper///depot/google3/googlemac/iPhone/Bigtop/ShareExtension/EmailValidation.m?cl=104323113
// Implementation is based on google3/javascript/closure/format/internationalizedemailaddress.js

static NSString *const kLocalMatcher =
    @"[+a-zA-Z0-9_.!#$%%&\'*\\/=?^`{|}~\\u0080-\uFFFFFF-]+";
static NSString *const kDomainMatcher =
    @"[a-zA-Z0-9\\u0080-\u3001\u3003-\uFF0D\uFF0F-\uFF60\uFF62-\uFFFFFF-]+";

@interface FIRAuthFakeBackendEmailValidator ()

// Return a character set with all ASCII and UNICODE periods that are valid for email addresses.
+ (NSCharacterSet *)characterSetWithPeriods;

// Returns YES if the whole string matches the regex, NO otherwise.
+ (BOOL)wholeString:(NSString *)wholeString
       matchesRegex:(NSString *)regexString;
@end

@implementation FIRAuthFakeBackendEmailValidator

+ (NSCharacterSet *)characterSetWithPeriods {
  return [NSCharacterSet characterSetWithCharactersInString:@".\uFF0E\u3002\uFF61"];
}

+ (BOOL)wholeString:(NSString *)wholeString
       matchesRegex:(NSString *)regexString {
  NSError *error = nil;
  NSRegularExpression *regex =
      [NSRegularExpression regularExpressionWithPattern:regexString
                                                options:NSRegularExpressionCaseInsensitive
                                                  error:&error];
  if (!regex || error) {
    return NO;
  }
  NSRange range = NSMakeRange(0, [wholeString length]);
  NSArray *matches = [regex matchesInString:wholeString options:NSMatchingAnchored range:range];
  if (![matches count]) {
    return NO;
  }
  for (NSTextCheckingResult *result in [matches reverseObjectEnumerator]) {
    if (result.range.location == range.location && result.range.length == range.length) {
      return YES;
    }
  }
  return NO;
}

+ (BOOL)isValidEmailAddress:(NSString *)emailAddress {
  // First split by the @ symbol.  There should be two parts and their lengths should be non-zero.
  NSArray *mainParts = [emailAddress componentsSeparatedByString:@"@"];
  if ([mainParts count] != 2 ||
      ![[mainParts firstObject] length] ||
      ![[mainParts lastObject] length]) {
    return NO;
  }

  // Verify the local part of the email address.
  BOOL localIsValid = [self wholeString:[mainParts firstObject] matchesRegex:kLocalMatcher];
  if (!localIsValid) {
    return NO;
  }

  // Split the domain into its parts for validation.  There must be at least two parts (cannot have
  // just a TLD).
  NSArray *domainParts =
      [[mainParts lastObject] componentsSeparatedByCharactersInSet:[self characterSetWithPeriods]];
  if ([domainParts count] < 2) {
    return NO;
  }

  // Validate each domain part.
  for (NSString *domainPart in domainParts) {
    // There cannot be two consecutive periods.
    if ([domainPart length] == 0) {
      return NO;
    }

    // Top Level Domains cannot be shorter than 2 characters long and cannot be longer than 63.
    if (domainPart == [domainParts lastObject] &&
        (([domainPart length] < 2) || ([domainPart length] > 63))) {
      return NO;
    }

    BOOL isDomainPartValid = [self wholeString:domainPart matchesRegex:kDomainMatcher];
    if (!isDomainPartValid) {
      return NO;
    }
  }
  // Well it seems that this email address is ok for now.
  return YES;
}

@end
