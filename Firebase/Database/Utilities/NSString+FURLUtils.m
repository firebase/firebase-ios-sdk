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

#import "NSString+FURLUtils.h"

@implementation NSString (FURLUtils)

- (NSString *) urlDecoded {
    NSString* replaced = [self stringByReplacingOccurrencesOfString:@"+" withString:@" "];
#if TARGET_OS_TV
    NSString* decoded = [replaced stringByAddingPercentEncodingWithAllowedCharacters:
                         [NSCharacterSet URLFragmentAllowedCharacterSet]];
#else
    NSString* decoded = [replaced stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
#endif
    // This is kind of a hack, but is generally how the js client works. We could run into trouble if
    // some piece is a correctly escaped %-sequence, and another isn't. But, that's bad input anyways...
    if (decoded) {
        return decoded;
    } else {
        return replaced;
    }
}

- (NSString *) urlEncoded {
#if TARGET_OS_TV
  return [self stringByAddingPercentEncodingWithAllowedCharacters:
          [NSCharacterSet URLFragmentAllowedCharacterSet]];
#else
  CFStringRef urlString = CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)self, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8);
  return (__bridge NSString *) urlString;
#endif
}

@end
