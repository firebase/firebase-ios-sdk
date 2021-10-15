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

#import "FirebaseDatabase/Sources/Utilities/FValidation.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Utilities/FTypedefs.h"

// Have to escape:  * ? + [ ( ) { } ^ $ | \ . /
// See:
// https://developer.apple.com/library/mac/#documentation/Foundation/Reference/NSRegularExpression_Class/Reference/Reference.html

NSString *const kInvalidPathCharacters = @"[].#$";
NSString *const kInvalidKeyCharacters = @"[].#$/";

@implementation FValidation

+ (void)validateFrom:(NSString *)fn writablePath:(FPath *)path {
    if ([[path getFront] isEqualToString:kDotInfoPrefix]) {
        @throw [[NSException alloc]
            initWithName:@"WritablePathValidation"
                  reason:[NSString
                             stringWithFormat:@"(%@) failed to path %@: Can't "
                                              @"modify data under %@",
                                              fn, [path description],
                                              kDotInfoPrefix]
                userInfo:nil];
    }
}

+ (void)validateFrom:(NSString *)fn knownEventType:(FIRDataEventType)event {
    switch (event) {
    case FIRDataEventTypeValue:
    case FIRDataEventTypeChildAdded:
    case FIRDataEventTypeChildChanged:
    case FIRDataEventTypeChildMoved:
    case FIRDataEventTypeChildRemoved:
        return;
        break;
    default:
        @throw [[NSException alloc]
            initWithName:@"KnownEventTypeValidation"
                  reason:[NSString
                             stringWithFormat:@"(%@) Unknown event type: %d",
                                              fn, (int)event]
                userInfo:nil];
        break;
    }
}

+ (BOOL)isValidPathString:(NSString *)pathString {
    static dispatch_once_t token;
    static NSCharacterSet *badPathChars = nil;
    dispatch_once(&token, ^{
      badPathChars = [NSCharacterSet
          characterSetWithCharactersInString:kInvalidPathCharacters];
    });
    return pathString != nil && [pathString length] != 0 &&
           [pathString rangeOfCharacterFromSet:badPathChars].location ==
               NSNotFound;
}

+ (void)validateFrom:(NSString *)fn validPathString:(NSString *)pathString {
    if (![self isValidPathString:pathString]) {
        @throw [[NSException alloc]
            initWithName:@"InvalidPathValidation"
                  reason:[NSString stringWithFormat:
                                       @"(%@) Must be a non-empty string and "
                                       @"not contain '.' '#' '$' '[' or ']'",
                                       fn]
                userInfo:nil];
    }
}

+ (void)validateFrom:(NSString *)fn validRootPathString:(NSString *)pathString {
    static dispatch_once_t token;
    static NSRegularExpression *dotInfoRegex = nil;
    dispatch_once(&token, ^{
      dotInfoRegex = [NSRegularExpression
          regularExpressionWithPattern:@"^\\/*\\.info(\\/|$)"
                               options:0
                                 error:nil];
    });

    NSString *tempPath = pathString;
    // HACK: Obj-C regex are kinda' slow.  Do a plain string search first before
    // bothering with the regex.
    if ([pathString rangeOfString:@".info"].location != NSNotFound) {
        tempPath = [dotInfoRegex
            stringByReplacingMatchesInString:pathString
                                     options:0
                                       range:NSMakeRange(0, pathString.length)
                                withTemplate:@"/"];
    }
    [self validateFrom:fn validPathString:tempPath];
}

+ (BOOL)isValidKey:(NSString *)key {
    static dispatch_once_t token;
    static NSCharacterSet *badKeyChars = nil;
    dispatch_once(&token, ^{
      badKeyChars = [NSCharacterSet
          characterSetWithCharactersInString:kInvalidKeyCharacters];
    });
    return key != nil && key.length > 0 &&
           [key rangeOfCharacterFromSet:badKeyChars].location == NSNotFound;
}

+ (void)validateFrom:(NSString *)fn validKey:(NSString *)key {
    if (![self isValidKey:key]) {
        @throw [[NSException alloc]
            initWithName:@"InvalidKeyValidation"
                  reason:[NSString
                             stringWithFormat:
                                 @"(%@) Must be a non-empty string and not "
                                 @"contain '/' '.' '#' '$' '[' or ']'",
                                 fn]
                userInfo:nil];
    }
}

+ (void)validateFrom:(NSString *)fn validURL:(FParsedUrl *)parsedUrl {
    NSString *pathString = [parsedUrl.path description];
    [self validateFrom:fn validRootPathString:pathString];
}
@end
