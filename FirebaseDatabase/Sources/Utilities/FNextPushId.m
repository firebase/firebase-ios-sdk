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

+ (NSString *)nextAfter:(NSString *_Nonnull)key {
    NSInteger keyAsInt;
    if ([FUtilities tryParseStringToInt:key asInt:&keyAsInt]) {
        return [FUtilities
            ieee754StringForNumber:[NSNumber
                                       numberWithInteger:(keyAsInt + 1)]];
    }
    NSString *charFormat = @"%C";
    NSMutableString *next = [NSMutableString stringWithCapacity:[key length]];
    unsigned long i;
    for (i = [key length] - 1;
        i >= 0 && [key characterAtIndex:i] == [PUSH_CHARS characterAtIndex: [PUSH_CHARS length] - 1];
        i--) {
        [next replaceCharactersInRange:NSMakeRange(i, 1) withString:[NSString stringWithFormat:charFormat, [PUSH_CHARS characterAtIndex:i]]];
    }
    if (i == -1) {
        [next appendFormat:charFormat, [PUSH_CHARS characterAtIndex:0]];
    } else {
        NSString * source = [NSString stringWithFormat:charFormat, [key characterAtIndex:i]];
        NSString * sourcePlusOne = [NSString stringWithFormat:charFormat, [PUSH_CHARS characterAtIndex: [PUSH_CHARS rangeOfString:source].location + 1]];
        [next replaceCharactersInRange:NSMakeRange(i, 1) withString:sourcePlusOne];
    }
    while (--i >= 0) {
        [next replaceCharactersInRange:NSMakeRange(i, 1) withString:[NSString stringWithFormat:charFormat, [key characterAtIndex:i]]];
    }
    return next;
}

@end
