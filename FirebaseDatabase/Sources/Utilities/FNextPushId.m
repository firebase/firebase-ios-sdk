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
#import "FirebaseDatabase/Sources/Utilities/FValidation.h"

static NSString *const PUSH_CHARS =
    @"-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz";

static NSString *const MIN_PUSH_CHAR = @" ";

static NSString *const MAX_PUSH_CHAR = @"\uFFFF";

static NSInteger const MAX_KEY_LEN = 786;

static unichar const LOW_SURROGATE_PAIR_START = 0xDC00;
static unichar const LOW_SURROGATE_PAIR_END = 0xDFFF;
static unichar const HIGH_SURROGATE_PAIR_START = 0xD800;
static unichar const HIGH_SURROGATE_PAIR_END = 0xDBFF;

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

+ (NSString *)from:(NSString *)fn successor:(NSString *_Nonnull)key {
    [FValidation validateFrom:fn validKey:key];
    NSInteger keyAsInt;
    if ([FUtilities tryParseString:key asInt:&keyAsInt]) {
        if (keyAsInt == [FUtilities int32max]) {
            return MIN_PUSH_CHAR;
        }
        return [NSString stringWithFormat:@"%ld", (long)keyAsInt + 1];
    }
    NSMutableString *next = [NSMutableString stringWithString:key];
    if ([next length] < MAX_KEY_LEN) {
        [next insertString:MIN_PUSH_CHAR atIndex:[key length]];
        return next;
    }

    long i = [next length] - 1;
    while (i >= 0) {
        if ([next characterAtIndex:i] != [MAX_PUSH_CHAR characterAtIndex:0]) {
            break;
        }
        --i;
    }

    // `nextAfter` was called on the largest possible key, so return the
    // maxName, which sorts larger than all keys.
    if (i == -1) {
        return [FUtilities maxName];
    }

    unichar character = [next characterAtIndex:i];
    unichar plusOne = character + 1;
    BOOL removePreviousCharacter = NO;
    BOOL replaceWithLowestSurrogatePair = NO;
    switch (plusOne) {
    case 0x23: // '#'
    case 0x24: // '$'
        plusOne = 0x25;
        break;

    case 0x2E: // '.'
    case 0x2F: // '/'
        plusOne = 0x30;
        break;

    case 0x5B: // '['
        plusOne = 0x5C;
        break;

    case 0x5D: // ']'
        plusOne = 0x5E;
        break;

    case 0x7F: // control character: del
        plusOne = 0x80;
        break;

    case HIGH_SURROGATE_PAIR_START: // 0xD800
        // We added one to 0xD7FF and entered surrogate pair zone
        // Replace with the lowest surrogate pair here
        replaceWithLowestSurrogatePair = YES;

    case LOW_SURROGATE_PAIR_END + 1: // 0xE000
        // If the previous character is the highest surrogate value
        // then we increment to the value 0xE000 by replacing the surrogate
        // pair by the single value 0xE000 (the value of plusOne)
        // Otherwise we increment the high surrogate value and set the low
        // surrogate value to the lowest.
        if (i == 0) {
            // Error, encountered low surrogate without matching high surrogate
        } else {
            unichar high = [next characterAtIndex:i - 1];
            if (high == HIGH_SURROGATE_PAIR_END) { /* highest value for the high
                                                      part of the pair */
                // Replace pair with 0xE000 (the value of plusOne)
                removePreviousCharacter = YES;
            } else {
                high += 1;
                NSString *highStr = [NSString stringWithFormat:@"%C", high];

                [next replaceCharactersInRange:NSMakeRange(i - 1, i)
                                    withString:highStr];
                plusOne = LOW_SURROGATE_PAIR_START; /* lowest value for the low
                                                       part of the pair */
            }
        }
        break;
    }

    NSString *sourcePlusOne =
        replaceWithLowestSurrogatePair
            ? [NSString stringWithFormat:@"%C%C", HIGH_SURROGATE_PAIR_START,
                                         LOW_SURROGATE_PAIR_START]
            : [NSString stringWithFormat:@"%C", plusOne];

    NSInteger replaceLocation = i;
    NSInteger replaceLength = 1;
    if (removePreviousCharacter) {
        --replaceLocation;
        ++replaceLength;
    }

    [next replaceCharactersInRange:NSMakeRange(replaceLocation, replaceLength)
                        withString:sourcePlusOne];
    NSInteger length = i + 1;
    if (removePreviousCharacter) {
        --length;
    } else if (replaceWithLowestSurrogatePair) {
        ++length;
    }
    return [next substringWithRange:NSMakeRange(0, length)];
}

+ (NSString *)from:(NSString *)fn predecessor:(NSString *_Nonnull)key {
    [FValidation validateFrom:fn validKey:key];
    NSInteger keyAsInt;
    if ([FUtilities tryParseString:key asInt:&keyAsInt]) {
        if (keyAsInt == [FUtilities int32min]) {
            return [FUtilities minName];
        }
        return [NSString stringWithFormat:@"%ld", (long)keyAsInt - 1];
    }
    NSMutableString *next = [NSMutableString stringWithString:key];
    if ([next characterAtIndex:(next.length - 1)] ==
        [MIN_PUSH_CHAR characterAtIndex:0]) {
        if ([next length] == 1) {
            return
                [NSString stringWithFormat:@"%ld", (long)[FUtilities int32max]];
        }
        // If the last character is the smallest possible character, then the
        // next smallest string is the prefix of `key` without it.
        [next replaceCharactersInRange:NSMakeRange([next length] - 1, 1)
                            withString:@""];
        return next;
    }
    // Replace the last character with its immediate predecessor, and fill the
    // suffix of the key with MAX_PUSH_CHAR. This is the lexicographically
    // largest possible key smaller than `key`.
    NSUInteger i = next.length - 1;
    unichar character = [next characterAtIndex:i];
    unichar minusOne = character - 1;
    BOOL removePreviousCharacter = NO;
    BOOL replaceWithHighestSurrogatePair = NO;
    switch (minusOne) {
    // NOTE: We already handled the case of min char (0x20)
    case 0x23: // '#'
    case 0x24: // '$'
        minusOne = 0x22;
        break;

    case 0x2E: // '.'
    case 0x2F: // '/'
        minusOne = 0x2D;
        break;

    case 0x5B: // '['
        minusOne = 0x5A;
        break;

    case 0x5D: // ']'
        minusOne = 0x5C;
        break;

    case 0x7F: // control character: del
        minusOne = 0x7E;
        break;

    case LOW_SURROGATE_PAIR_END: // 0xDFFF
        // Previously we had 0xE000 which is a single utf16 character,
        // this needs to be replaced with the highest surrogate pair:
        replaceWithHighestSurrogatePair = YES;
        break;

    case HIGH_SURROGATE_PAIR_END: // 0xDBFF
        // If the previous character is the lowest high surrogate value
        // then we decrement to the non-surrogate value 0xD7FF by replacing the
        // surrogate pair by the single value 0xD7FF (HIGH_SURROGATE_PAIR_START
        // - 1) Otherwise we decrement the high surrogate value and set the low
        // surrogate value to the highest.
        if (i == 0) {
            // Error, found low surrogate without matching high surrogate
        } else {
            unichar high = [next characterAtIndex:i - 1];
            if (high == HIGH_SURROGATE_PAIR_START) { /* lowest value for the
                                                        high part of the pair */
                // Replace pair with single 0xD7FF value
                removePreviousCharacter = YES;
                minusOne = HIGH_SURROGATE_PAIR_START - 1;
            } else {
                high -= 1;
                NSString *highStr = [NSString stringWithFormat:@"%C", high];

                [next replaceCharactersInRange:NSMakeRange(i - 1, i)
                                    withString:highStr];
                minusOne = LOW_SURROGATE_PAIR_END; /* highest value for the low
                                                      part of the pair */
            }
        }
        break;
    }

    NSString *sourceMinusOne =
        replaceWithHighestSurrogatePair
            ? [NSString stringWithFormat:@"%C%C", HIGH_SURROGATE_PAIR_END,
                                         LOW_SURROGATE_PAIR_END]
            : [NSString stringWithFormat:@"%C", minusOne];

    NSInteger replaceLocation = i;
    NSInteger replaceLength = 1;
    if (removePreviousCharacter) {
        --replaceLocation;
        ++replaceLength;
    }

    [next replaceCharactersInRange:NSMakeRange(replaceLocation, replaceLength)
                        withString:sourceMinusOne];

    NSInteger length = i + 1;
    if (removePreviousCharacter) {
        --length;
    } else if (replaceWithHighestSurrogatePair) {
        ++length;
    }
    return [next stringByPaddingToLength:MAX_KEY_LEN
                              withString:MAX_PUSH_CHAR
                         startingAtIndex:0];
};

@end
