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

#import "FirebaseDatabase/Tests/Helpers/FTestAuthTokenGenerator.h"
#import <CommonCrypto/CommonHMAC.h>
#import "FirebaseDatabase/Tests/third_party/Base64.h"

@implementation FTestAuthTokenGenerator

+ (NSString *)jsonStringForData:(id)data {
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:kNilOptions error:nil];

  return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

+ (NSNumber *)tokenVersion {
  return @0;
}

+ (NSMutableDictionary *)createOptionsClaims:(NSDictionary *)options {
  NSMutableDictionary *claims = [[NSMutableDictionary alloc] init];
  if (options) {
    NSDictionary *map = @{
      @"expires" : @"exp",
      @"notBefore" : @"nbf",
      @"admin" : @"admin",
      @"debug" : @"debug",
      @"simulate" : @"simulate"
    };

    for (NSString *claim in map) {
      if (options[claim] != nil) {
        NSString *claimName = [map objectForKey:claim];
        id val = [options objectForKey:claim];
        [claims setObject:val forKey:claimName];
      }
    }
  }
  return claims;
}

+ (NSString *)webSafeBase64:(NSString *)encoded {
  return [[[encoded stringByReplacingOccurrencesOfString:@"=" withString:@""]
      stringByReplacingOccurrencesOfString:@"+"
                                withString:@"-"] stringByReplacingOccurrencesOfString:@"/"
                                                                           withString:@"_"];
}

+ (NSString *)base64EncodeString:(NSString *)target {
  return [self webSafeBase64:[target base64EncodedString]];
}

+ (NSString *)tokenWithClaims:(NSDictionary *)claims andSecret:(NSString *)secret {
  NSDictionary *headerData = @{@"typ" : @"JWT", @"alg" : @"HS256"};
  NSString *encodedHeader = [self base64EncodeString:[self jsonStringForData:headerData]];
  NSString *encodedClaims = [self base64EncodeString:[self jsonStringForData:claims]];

  NSString *secureBits = [NSString stringWithFormat:@"%@.%@", encodedHeader, encodedClaims];

  const char *cKey = [secret cStringUsingEncoding:NSUTF8StringEncoding];
  const char *cData = [secureBits cStringUsingEncoding:NSUTF8StringEncoding];
  unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
  CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
  NSData *hmac = [NSData dataWithBytesNoCopy:cHMAC length:CC_SHA256_DIGEST_LENGTH freeWhenDone:NO];
  NSString *encodedHmac = [self webSafeBase64:[hmac base64EncodedString]];
  return [NSString stringWithFormat:@"%@.%@.%@", encodedHeader, encodedClaims, encodedHmac];
}

+ (NSString *)tokenWithSecret:(NSString *)secret
                     authData:(NSDictionary *)data
                   andOptions:(NSDictionary *)options {
  NSMutableDictionary *claims = [self createOptionsClaims:options];
  [claims setObject:[self tokenVersion] forKey:@"v"];
  NSNumber *now = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
  [claims setObject:now forKey:@"iat"];
  [claims setObject:data forKey:@"d"];
  return [self tokenWithClaims:claims andSecret:secret];
}

@end
