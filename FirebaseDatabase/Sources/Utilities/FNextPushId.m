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

#import "FirebaseDatabase/Sources/Utilities/FNextPushId.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"

static NSString *const PUSH_CHARS =
    @"-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz";

static NSString *const MIN_PUSH_CHAR = @"-";

static NSString *const MAX_PUSH_CHAR = @"z";

static NSInteger const MAX_KEY_LEN = 786;

@implementation FNextPushId

+ (NSString *)get:(NSTimeInterval)currentTime {
    static long long lastPushTime = 0;
    static int lastRandChars[12];

    long long now = (long long)(currentTime * 1000);

    BOOL duplicateTime = now == lastPushTime;
    lastPushTime = now;

    unichar timeStampChars[8];
    for (int i = 7; i >= 0; i--) {
        timeStampChars[i] = [PUSH_CHARS characterAtIndex:(now % 64)];
        now = (long long)floor(now / 64);
    }

    NSMutableString *id = [[NSMutableString alloc] init];
    [id appendString:[NSString stringWithCharacters:timeStampChars length:8]];

    if (!duplicateTime) {
        for (int i = 0; i < 12; i++) {
            lastRandChars[i] = (int)floor(arc4random() % 64);
        }
    } else {
        int i = 0;
        for (i = 11; i >= 0 && lastRandChars[i] == 63; i--) {
            lastRandChars[i] = 0;
        }
        lastRandChars[i]++;
    }

    for (int i = 0; i < 12; i++) {
        [id appendFormat:@"%C", [PUSH_CHARS characterAtIndex:lastRandChars[i]]];
    }

    return [NSString stringWithString:id];
}

+ (NSString *)successor:(NSString *_Nonnull)key {
    NSInteger keyAsInt;
    if ([FUtilities tryParseStringToInt:key asInt:&keyAsInt]) {
        if (keyAsInt == NSIntegerMax) {
            return MIN_PUSH_CHAR;
        }
        return [NSString stringWithFormat:@"%ld", (long)keyAsInt + 1];
    }
    NSMutableString *next = [NSMutableString stringWithString:key];
    if ([next length] < MAX_KEY_LEN) {
        [next insertString:MIN_PUSH_CHAR atIndex:[key length]];
        return next;
    }

    unsigned long i = [next length] - 1;

    while (i >= 0 &&
           [next characterAtIndex:i] == [MAX_PUSH_CHAR characterAtIndex:0]) {
        i--;
    }

    // `nextAfter` was called on the largest possible key, so return the
    // maxName, which sorts larger than all keys.
    if (i == -1) {
        return [FUtilities maxName];
    }

    NSString *source =
        [NSString stringWithFormat:@"%C", [next characterAtIndex:i]];
    NSInteger sourceIndex = [PUSH_CHARS rangeOfString:source].location;
    NSString *sourcePlusOne = [NSString
        stringWithFormat:@"%C", [PUSH_CHARS characterAtIndex:sourceIndex + 1]];

    [next replaceCharactersInRange:NSMakeRange(i, i + 1)
                        withString:sourcePlusOne];
    return [next substringWithRange:NSMakeRange(0, i + 1)];
}

// `key` is assumed to be non-empty.
+ (NSString *)predecessor:(NSString *_Nonnull)key {
    NSInteger keyAsInt;
    if ([FUtilities tryParseStringToInt:key asInt:&keyAsInt]) {
        if (keyAsInt == [FUtilities int32min]) {
            return [FUtilities minName];
        }
        return [NSString stringWithFormat:@"%ld", (long)keyAsInt - 1];
    }
    NSMutableString *next = [NSMutableString stringWithString:key];
    if ([[next substringWithRange:NSMakeRange(next.length - 1, 1)]
            isEqualToString:MIN_PUSH_CHAR]) {
        if ([next length] == 1) {
            return [FUtilities minName];
        }
        // If the last character is the smallest possible character, then the
        // next smallest string is the prefix of `key` without it.
        [next replaceCharactersInRange:NSMakeRange([next length] - 1, 1)
                            withString:@""];
        return next;
    }
    // Replace the last character with it's immedate predecessor, and fill the
    // suffix of the key with MAX_PUSH_CHAR. This is the lexicographically
    // largest possible key smaller than `key`.
    NSString *curr =
        [next substringWithRange:NSMakeRange([next length] - 1, 1)];
    NSRange dstRange = NSMakeRange([next length] - 1, 1);
    NSRange srcRange = [PUSH_CHARS rangeOfString:curr];
    srcRange.location -= 1;
    [next replaceCharactersInRange:dstRange
                        withString:[PUSH_CHARS substringWithRange:srcRange]];
    return [next stringByPaddingToLength:MAX_KEY_LEN
                              withString:MAX_PUSH_CHAR
                         startingAtIndex:0];
};

@end
