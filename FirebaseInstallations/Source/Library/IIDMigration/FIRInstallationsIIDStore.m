/*
 * Copyright 2019 Google
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

#import "FIRInstallationsIIDStore.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import <CommonCrypto/CommonDigest.h>

static NSString *const kFIRInstallationsIIDKeyPairPublicTagPrefix = @"com.google.iid.keypair.public-";
static NSString *const kFIRInstallationsIIDKeyPairPrivateTagPrefix = @"com.google.iid.keypair.private-";

@implementation FIRInstallationsIIDStore

- (FBLPromise<NSString *> *)existingIID {
  return [FBLPromise resolvedWith:@""];
}

- (FBLPromise<NSNull *> *)deleteExistingIID {
  return [FBLPromise resolvedWith:[NSNull null]];
}

- (NSString *)IIDWithPublicKeyData:(NSData *)publicKeyData {
  NSData *publicKeySHA1 = [self sha1WithData:publicKeyData];

  const uint8_t *bytes = publicKeySHA1.bytes;
  NSMutableData *identityData = [NSMutableData dataWithData:publicKeySHA1];

  uint8_t b0 = bytes[0];
  // Take the first byte and make the initial four 7 by initially making the initial 4 bits 0
  // and then adding 0x70 to it.
  b0 = 0x70 + (0xF & b0);
  // failsafe should give you back b0 itself
  b0 = (b0 & 0xFF);
  [identityData replaceBytesInRange:NSMakeRange(0, 1) withBytes:&b0];
  NSData *data = [identityData subdataWithRange:NSMakeRange(0, 8 * sizeof(Byte))];
  return [self base64URLEncodedStringWithData:data];
}

- (NSData *)sha1WithData:(NSData *)data {
  unsigned int outputLength = CC_SHA1_DIGEST_LENGTH;
  unsigned char output[outputLength];
  unsigned int length = (unsigned int)[data length];

  CC_SHA1(data.bytes, length, output);
  return [NSData dataWithBytes:output length:outputLength];
}

- (NSString *)base64URLEncodedStringWithData:(NSData *)data {
  NSString *string = [data base64EncodedStringWithOptions:0];
  string = [string stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
  string = [string stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
  return string;
}


//- (NSString *)webSafeBase64WithData:(NSData *)inData {
//  int shift_ = 0;
//  BOOL doPad_ = NO;
//  int padLen_ = 0;
//  unsigned int mask_ = 0;
//  char *charMap_;
//
//  NSUInteger inLen = [inData length];
//  if (inLen <= 0) {
//    // Empty input
//    return @"";
//  }
//  unsigned char *inBuf = (unsigned char *)[inData bytes];
//  NSUInteger inPos = 0;
//
//  NSUInteger outLen = (inLen * 8 + shift_ - 1) / shift_;
//  if (doPad_) {
//    outLen = ((outLen + padLen_ - 1) / padLen_) * padLen_;
//  }
//  NSMutableData *outData = [NSMutableData dataWithLength:outLen];
//  unsigned char *outBuf = (unsigned char *)[outData mutableBytes];
//  NSUInteger outPos = 0;
//
//  unsigned int buffer = inBuf[inPos++];
//  int bitsLeft = 8;
//  while (bitsLeft > 0 || inPos < inLen) {
//    if (bitsLeft < shift_) {
//      if (inPos < inLen) {
//        buffer <<= 8;
//        buffer |= (inBuf[inPos++] & 0xff);
//        bitsLeft += 8;
//      } else {
//        int pad = shift_ - bitsLeft;
//        buffer <<= pad;
//        bitsLeft += pad;
//      }
//    }
//    unsigned int idx = (buffer >> (bitsLeft - shift_)) & mask_;
//    bitsLeft -= shift_;
//    outBuf[outPos++] = charMap_[idx];
//  }
//
//  if (doPad_) {
//    while (outPos < outLen) outBuf[outPos++] = paddingChar_;
//  }
//
//  if (outPos != outLen) {
//    FIRInstanceIDLoggerError(kFIRInstanceIDStringEncodingBufferUnderflow,
//                             @"Underflowed output buffer");
//    return nil;
//  }
//  [outData setLength:outPos];
//
//  return [[NSString alloc] initWithData:outData encoding:NSASCIIStringEncoding];
//}

#pragma mark - Keychain



#pragma mark - Plist

- (BOOL)hasPlistIIDFlag {
  NSString *path = [self plistPath];
  if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
    return NO;
  }

  return [[NSDictionary alloc] initWithContentsOfFile:path];
}

- (NSString *)plistPath {
  NSString *plistNameWithExtension = @"g-checkin.plist";
  NSString *_subDirectoryName = @"Google/FirebaseInstanceID";

  NSArray *directoryPaths =
  NSSearchPathForDirectoriesInDomains([self supportedDirectory], NSUserDomainMask, YES);
  NSArray *components = @[ directoryPaths.lastObject, _subDirectoryName, plistNameWithExtension ];

  return [NSString pathWithComponents:components];
}

- (NSSearchPathDirectory)supportedDirectory {
#if TARGET_OS_TV
  return NSCachesDirectory;
#else
  return NSApplicationSupportDirectory;
#endif
}

@end
