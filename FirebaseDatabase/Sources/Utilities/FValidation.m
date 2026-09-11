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

#import "FValidation.h"
#import "FConstants.h"
#import "FParsedUrl.h"
#import "FTypedefs.h"

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

#pragma mark -
#pragma mark Authentication validation

+ (BOOL)stringNonempty:(NSString *)str {
    return str != nil && ![str isKindOfClass:[NSNull class]] && str.length > 0;
}

+ (void)validateToken:(NSString *)token {
    if (![FValidation stringNonempty:token]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Can't have empty string or nil for custom token"];
    }
}

#pragma mark -
#pragma mark Handling authentication errors

/**
 * This function immediately calls the callback.
 * It assumes that it is not on FirebaseWorker thread.
 * It assumes it's on a user-controlled thread.
 */
+ (void)handleError:(NSError *)error
    withUserCallback:(fbt_void_nserror_id)userCallback {
    if (userCallback) {
        userCallback(error, nil);
    }
}

/**
 * This function immediately calls the callback.
 * It assumes that it is not on FirebaseWorker thread.
 * It assumes it's on a user-controlled thread.
 */
+ (void)handleError:(NSError *)error
    withSuccessCallback:(fbt_void_nserror)userCallback {
    if (userCallback) {
        userCallback(error);
    }
}

#pragma mark -
#pragma mark Snapshot validation

+ (BOOL)validateFrom:(NSString *)fn
    isValidLeafValue:(id)value
            withPath:(NSArray *)path {
    if ([value isKindOfClass:[NSString class]]) {
        // Try to avoid conversion to bytes if possible
        NSString *theString = value;
        if ([theString maximumLengthOfBytesUsingEncoding:NSUTF8StringEncoding] >
                kFirebaseMaxLeafSize &&
            [theString lengthOfBytesUsingEncoding:NSUTF8StringEncoding] >
                kFirebaseMaxLeafSize) {
            NSRange range;
            range.location = 0;
            range.length = MIN(path.count, 50);
            NSString *pathString =
                [[path subarrayWithRange:range] componentsJoinedByString:@"."];
            @throw [[NSException alloc]
                initWithName:@"InvalidFirebaseData"
                      reason:[NSString
                                 stringWithFormat:@"(%@) String exceeds max "
                                                  @"size of %u utf8 bytes: %@",
                                                  fn, (int)kFirebaseMaxLeafSize,
                                                  pathString]
                    userInfo:nil];
        }
        return YES;
    }

    else if ([value isKindOfClass:[NSNumber class]]) {
        // Cannot store NaN, but otherwise can store NSNumbers.
        if ([[NSDecimalNumber notANumber] isEqualToNumber:value]) {
            NSRange range;
            range.location = 0;
            range.length = MIN(path.count, 50);
            NSString *pathString =
                [[path subarrayWithRange:range] componentsJoinedByString:@"."];
            @throw [[NSException alloc]
                initWithName:@"InvalidFirebaseData"
                      reason:[NSString
                                 stringWithFormat:
                                     @"(%@) Cannot store NaN at path: %@.", fn,
                                     pathString]
                    userInfo:nil];
        }
        return YES;
    }

    else if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dval = value;
        if (dval[kServerValueSubKey] != nil) {
            if ([dval count] > 1) {
                NSRange range;
                range.location = 0;
                range.length = MIN(path.count, 50);
                NSString *pathString = [[path subarrayWithRange:range]
                    componentsJoinedByString:@"."];
                @throw [[NSException alloc]
                    initWithName:@"InvalidFirebaseData"
                          reason:[NSString stringWithFormat:
                                               @"(%@) Cannot store other keys "
                                               @"with server value keys.%@.",
                                               fn, pathString]
                        userInfo:nil];
            }
            return YES;
        }
        return NO;
    }

    else if (value == [NSNull null] || value == nil) {
        // Null is valid type to store at leaf
        return YES;
    }

    return NO;
}

+ (NSString *)parseAndValidateKey:(id)keyId
                     fromFunction:(NSString *)fn
                             path:(NSArray *)path {
    if (![keyId isKindOfClass:[NSString class]]) {
        NSRange range;
        range.location = 0;
        range.length = MIN(path.count, 50);
        NSString *pathString =
            [[path subarrayWithRange:range] componentsJoinedByString:@"."];
        @throw [[NSException alloc]
            initWithName:@"InvalidFirebaseData"
                  reason:[NSString
                             stringWithFormat:@"(%@) Non-string keys are not "
                                              @"allowed in object at path: %@",
                                              fn, pathString]
                userInfo:nil];
    }
    return (NSString *)keyId;
}

+ (void)validateFrom:(NSString *)fn
    validDictionaryKey:(id)keyId
              withPath:(NSArray *)path {
    NSString *key = [self parseAndValidateKey:keyId fromFunction:fn path:path];
    if (![key isEqualToString:kPayloadPriority] &&
        ![key isEqualToString:kPayloadValue] &&
        ![key isEqualToString:kServerValueSubKey] &&
        ![FValidation isValidKey:key]) {
        NSRange range;
        range.location = 0;
        range.length = MIN(path.count, 50);
        NSString *pathString =
            [[path subarrayWithRange:range] componentsJoinedByString:@"."];
        @throw [[NSException alloc]
            initWithName:@"InvalidFirebaseData"
                  reason:[NSString stringWithFormat:
                                       @"(%@) Invalid key in object at path: "
                                       @"%@. Keys must be non-empty and cannot "
                                       @"contain '/' '.' '#' '$' '[' or ']'",
                                       fn, pathString]
                userInfo:nil];
    }
}

+ (void)validateFrom:(NSString *)fn
    validUpdateDictionaryKey:(id)keyId
                   withValue:(id)value {
    FPath *path = [FPath pathWithString:[self parseAndValidateKey:keyId
                                                     fromFunction:fn
                                                             path:@[]]];
    __block NSInteger keyNum = 0;
    [path enumerateComponentsUsingBlock:^void(NSString *key, BOOL *stop) {
      if ([key isEqualToString:kPayloadPriority] &&
          keyNum == [path length] - 1) {
          [self validateFrom:fn isValidPriorityValue:value withPath:@[]];
      } else {
          keyNum++;

          if (![FValidation isValidKey:key]) {
              @throw [[NSException alloc]
                  initWithName:@"InvalidFirebaseData"
                        reason:[NSString
                                   stringWithFormat:
                                       @"(%@) Invalid key in object. Keys must "
                                       @"be non-empty and cannot contain '.' "
                                       @"'#' '$' '[' or ']'",
                                       fn]
                      userInfo:nil];
          }
      }
    }];
}

+ (void)validateFrom:(NSString *)fn
    isValidPriorityValue:(id)value
                withPath:(NSArray *)path {
    [self validateFrom:fn
        isValidPriorityValue:value
                    withPath:path
                  throwError:YES];
}

/**
 * Returns YES if priority is valid.
 */
+ (BOOL)validatePriorityValue:value {
    return [self validateFrom:nil
         isValidPriorityValue:value
                     withPath:nil
                   throwError:NO];
}

/**
 * Helper for validating priorities.  If passed YES for throwError, it'll throw
 * descriptive errors on validation problems.  Else, it'll just return YES/NO.
 */
+ (BOOL)validateFrom:(NSString *)fn
    isValidPriorityValue:(id)value
                withPath:(NSArray *)path
              throwError:(BOOL)throwError {
    if ([value isKindOfClass:[NSNumber class]]) {
        if ([[NSDecimalNumber notANumber] isEqualToNumber:value]) {
            if (throwError) {
                NSRange range;
                range.location = 0;
                range.length = MIN(path.count, 50);
                NSString *pathString = [[path subarrayWithRange:range]
                    componentsJoinedByString:@"."];
                @throw [[NSException alloc]
                    initWithName:@"InvalidFirebaseData"
                          reason:[NSString stringWithFormat:
                                               @"(%@) Cannot store NaN as "
                                               @"priority at path: %@.",
                                               fn, pathString]
                        userInfo:nil];
            } else {
                return NO;
            }
        } else if (value == (id)kCFBooleanFalse ||
                   value == (id)kCFBooleanTrue) {
            if (throwError) {
                NSRange range;
                range.location = 0;
                range.length = MIN(path.count, 50);
                NSString *pathString = [[path subarrayWithRange:range]
                    componentsJoinedByString:@"."];
                @throw [[NSException alloc]
                    initWithName:@"InvalidFirebaseData"
                          reason:[NSString stringWithFormat:
                                               @"(%@) Cannot store true/false "
                                               @"as priority at path: %@.",
                                               fn, pathString]
                        userInfo:nil];
            } else {
                return NO;
            }
        }
    } else if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dval = value;
        if (dval[kServerValueSubKey] != nil) {
            if ([dval count] > 1) {
                if (throwError) {
                    NSRange range;
                    range.location = 0;
                    range.length = MIN(path.count, 50);
                    NSString *pathString = [[path subarrayWithRange:range]
                        componentsJoinedByString:@"."];
                    @throw [[NSException alloc]
                        initWithName:@"InvalidFirebaseData"
                              reason:[NSString
                                         stringWithFormat:
                                             @"(%@) Cannot store other keys "
                                             @"with server value keys as "
                                             @"priority at path: %@.",
                                             fn, pathString]
                            userInfo:nil];
                } else {
                    return NO;
                }
            }
        } else {
            if (throwError) {
                NSRange range;
                range.location = 0;
                range.length = MIN(path.count, 50);
                NSString *pathString = [[path subarrayWithRange:range]
                    componentsJoinedByString:@"."];
                @throw [[NSException alloc]
                    initWithName:@"InvalidFirebaseData"
                          reason:[NSString
                                     stringWithFormat:
                                         @"(%@) Cannot store an NSDictionary "
                                         @"as priority at path: %@.",
                                         fn, pathString]
                        userInfo:nil];
            } else {
                return NO;
            }
        }
    } else if ([value isKindOfClass:[NSArray class]]) {
        if (throwError) {
            NSRange range;
            range.location = 0;
            range.length = MIN(path.count, 50);
            NSString *pathString =
                [[path subarrayWithRange:range] componentsJoinedByString:@"."];
            @throw [[NSException alloc]
                initWithName:@"InvalidFirebaseData"
                      reason:[NSString stringWithFormat:
                                           @"(%@) Cannot store an NSArray as "
                                           @"priority at path: %@.",
                                           fn, pathString]
                    userInfo:nil];
        } else {
            return NO;
        }
    }

    // It's valid!
    return YES;
}
@end
