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

#import "FStringUtilities.h"
#import "NSData+SRB64Additions.h"
#import <CommonCrypto/CommonDigest.h>

@implementation FStringUtilities

// http://stackoverflow.com/questions/3468268/objective-c-sha1
// http://stackoverflow.com/questions/7310457/ios-objective-c-sha-1-and-base64-problem
+ (NSString *)base64EncodedSha1:(NSString *)str {
    const char *cstr = [str cStringUsingEncoding:NSUTF8StringEncoding];
    // NSString reports length in characters, but we want it in bytes, which
    // strlen will give us.
    unsigned long dataLen = strlen(cstr);
    NSData *data = [NSData dataWithBytes:cstr length:dataLen];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (unsigned int)data.length, digest);
    NSData *output = [[NSData alloc] initWithBytes:digest
                                            length:CC_SHA1_DIGEST_LENGTH];
    return [FSRUtilities base64EncodedStringFromData:output];
}

+ (NSString *)urlDecoded:(NSString *)url {
    NSString *replaced = [url stringByReplacingOccurrencesOfString:@"+"
                                                        withString:@" "];
    NSString *decoded = [replaced stringByRemovingPercentEncoding];
    // This is kind of a hack, but is generally how the js client works. We
    // could run into trouble if some piece is a correctly escaped %-sequence,
    // and another isn't. But, that's bad input anyways...
    if (decoded) {
        return decoded;
    } else {
        return replaced;
    }
}

+ (NSString *)urlEncoded:(NSString *)url {
    // Didn't seem like there was an Apple NSCharacterSet that had our version
    // of the encoding So I made my own, following RFC 2396
    // https://www.ietf.org/rfc/rfc2396.txt allowedCharacters = alphanum | "-" |
    // "_" | "~"
    NSCharacterSet *allowedCharacters = [NSCharacterSet
        characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGH"
                                           @"IJKLMNOPQRSTUVWXYZ0123456789-_~"];
    return [url
        stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
}

+ (NSString *)sanitizedForUserAgent:(NSString *)str {
    return
        [str stringByReplacingOccurrencesOfString:@"/|_"
                                       withString:@"|"
                                          options:NSRegularExpressionSearch
                                            range:NSMakeRange(0, [str length])];
}

@end
