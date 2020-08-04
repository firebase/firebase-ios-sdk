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

#import "FirebaseAppDistribution/Sources/FIRAppDistributionMachO.h"
#import <CommonCrypto/CommonHMAC.h>
#include <mach-o/arch.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import "FirebaseAppDistribution/Sources/FIRAppDistributionMachOSlice.h"

@interface FIRAppDistributionMachO ()
@property(nonatomic, copy) NSFileHandle* file;
@property(nonatomic, strong) NSMutableArray* slices;
@end

@implementation FIRAppDistributionMachO

- (instancetype)initWithPath:(NSString*)path {
  self = [super init];

  if (self) {
    _file = [NSFileHandle fileHandleForReadingAtPath:path];
    _slices = [NSMutableArray new];
    [self extractSlices];
  }
  return self;
}

- (void)extractSlices {
  uint32_t magicValue;

  struct fat_header fheader;
  NSData* data = [self.file readDataOfLength:sizeof(fheader)];
  [data getBytes:&fheader length:sizeof(fheader)];

  magicValue = CFSwapInt32BigToHost(fheader.magic);

  // Check to see if the file is a FAT binary (has multiple architectures)
  if (magicValue == FAT_MAGIC) {
    uint32_t archCount = CFSwapInt32BigToHost(fheader.nfat_arch);
    NSUInteger archOffsets[archCount];

    // Gather the offsets for each architecture
    for (uint32_t i = 0; i < archCount; i++) {
      struct fat_arch arch;

      data = [self.file readDataOfLength:sizeof(arch)];
      [data getBytes:&arch length:sizeof(arch)];

      archOffsets[i] = CFSwapInt32BigToHost(arch.offset);
    }

    // Iterate the slices based on the offsets we extracted above
    for (uint32_t i = 0; i < archCount; i++) {
      FIRAppDistributionMachOSlice* slice = [self extractSliceAtOffset:archOffsets[i]];

      if (slice) [_slices addObject:slice];
    }
  } else {
    // If the binary is not FAT, we're dealing with a single architecture
    FIRAppDistributionMachOSlice* slice = [self extractSliceAtOffset:0];

    if (slice) [_slices addObject:slice];
  }
}

- (FIRAppDistributionMachOSlice*)extractSliceAtOffset:(NSUInteger)offset {
  [self.file seekToFileOffset:offset];

  struct mach_header header;

  NSData* data = [self.file readDataOfLength:sizeof(header)];
  [data getBytes:&header length:sizeof(header)];
  uint32_t magicValue = CFSwapInt32BigToHost(header.magic);

  // If we didn't read a valid magic value, something is wrong
  // Bail out immediately to prevent reading random data
  if (magicValue != MH_CIGAM_64 && magicValue != MH_CIGAM) {
    return nil;
  }

  // If the binary is 64-bit, read the reserved bit and discard it
  if (magicValue == MH_CIGAM_64) {
    uint32_t reserved;

    [self.file readDataOfLength:sizeof(reserved)];
  }

  for (uint32_t i = 0; i < header.ncmds; i++) {
    struct load_command lc;

    data = [self.file readDataOfLength:sizeof(lc)];
    [data getBytes:&lc length:sizeof(lc)];

    if (lc.cmd != LC_UUID) {
      // Move to the next load command
      [self.file seekToFileOffset:[self.file offsetInFile] + lc.cmdsize - sizeof(lc)];
      continue;
    }

    // Re-read the load command, but this time as a UUID command
    // so we can easily fetch the UUID
    [self.file seekToFileOffset:[self.file offsetInFile] - sizeof(lc)];
    struct uuid_command uc;
    data = [self.file readDataOfLength:sizeof(uc)];
    [data getBytes:&uc length:sizeof(uc)];

    NSUUID* uuid = [[NSUUID alloc] initWithUUIDBytes:uc.uuid];
    const NXArchInfo* arch = NXGetArchInfoFromCpuType(header.cputype, header.cpusubtype);

    return [[FIRAppDistributionMachOSlice alloc] initWithArch:arch uuid:uuid];
  }

  // If we got here, something is wrong. We iterated the load commands
  // and didn't find a UUID load command. This means the binary is corrupt.
  return nil;
}

- (NSString*)codeHash {
  NSMutableString* prehashedString = [NSMutableString new];

  NSArray* sortedSlices =
      [_slices sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [[obj1 architectureName] compare:[obj2 architectureName]];
      }];

  for (FIRAppDistributionMachOSlice* slice in sortedSlices) {
    [prehashedString appendString:[slice uuidString]];
  }

  return [self sha1:prehashedString];
}

- (NSString*)sha1:(NSString*)prehashedString {
  NSData* data = [prehashedString dataUsingEncoding:NSUTF8StringEncoding];
  uint8_t digest[CC_SHA1_DIGEST_LENGTH];
  CC_SHA1(data.bytes, (int)data.length, digest);
  NSMutableString* hashedString = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
  for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) [hashedString appendFormat:@"%02x", digest[i]];

  return hashedString;
}
@end
