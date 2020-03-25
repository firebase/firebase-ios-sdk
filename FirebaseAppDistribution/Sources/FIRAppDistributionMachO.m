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

#import <mach-o/fat.h>
#import <mach-o/loader.h>
#include <mach-o/arch.h>
#import <CommonCrypto/CommonHMAC.h>
#import "FIRAppDistributionMachO.h"
#import "FIRAppDistributionMachOSlice.h"

@implementation FIRAppDistributionMachO

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    
    if (self) {
        _file = [NSFileHandle fileHandleForReadingAtPath:path];
        [_file seekToFileOffset:0];
        _slices = [NSMutableArray new];
    }
    
    [self extractSlices];
    
    return self;
}

- (void)extractSlices {
    uint32_t magicValue;
    
    struct fat_header fheader;
    NSData* data = [_file readDataOfLength:sizeof(fheader)];
    [data getBytes:&fheader length:sizeof(fheader)];
   
    magicValue = CFSwapInt32HostToBig(fheader.magic);
    
    if (magicValue == FAT_MAGIC || magicValue == FAT_CIGAM) {
        uint32_t archCount = CFSwapInt32HostToBig(fheader.nfat_arch);
        
        for (uint32_t i = 0; i < archCount; i++) {
            struct fat_arch arch;
            
            data = [_file readDataOfLength:sizeof(arch)];
            [data getBytes:&arch length:sizeof(arch)];

            FIRAppDistributionMachOSlice* slice = [self extractSliceAtOffset:arch.offset];
            [_slices addObject:slice];
        }
    } else {
        FIRAppDistributionMachOSlice* slice = [self extractSliceAtOffset:0];
        [_slices addObject:slice];
    }
}

-(FIRAppDistributionMachOSlice*)extractSliceAtOffset:(NSUInteger)offset {
    [_file seekToFileOffset:offset];
    
    struct mach_header header;
    
    NSData *data = [_file readDataOfLength:sizeof(header)];
    [data getBytes:&header length:sizeof(header)];
    uint32_t magicValue = CFSwapInt32HostToBig(header.magic);
    
    // TODO: Verify Mach-O

    // If binary is 64-bit, read reserved bit and discard it
    if (magicValue == MH_CIGAM_64) {
        uint32_t reserved;

        [_file readDataOfLength:sizeof(reserved)];
    }

    for (uint32_t i = 0; i < header.ncmds; i++) {
        struct load_command lc;
        
        data = [_file readDataOfLength:sizeof(lc)];
        [data getBytes:&lc length:sizeof(lc)];
        
        if (lc.cmd == LC_UUID) {
            [_file seekToFileOffset:[_file offsetInFile] - sizeof(lc)];
            struct uuid_command uc;
            data = [_file readDataOfLength:sizeof(uc)];
            [data getBytes:&uc length:sizeof(uc)];
            
            NSUUID* uuid = [[NSUUID alloc] initWithUUIDBytes:uc.uuid];
            const NXArchInfo* arch = NXGetArchInfoFromCpuType(header.cputype, header.cpusubtype);
            
            NSLog(@"Got Architecture %s UUID: %@", arch->name, [uuid UUIDString]);
            return [[FIRAppDistributionMachOSlice alloc]initWithArch:arch uuid:uuid];
        } else {
            [_file seekToFileOffset:[_file offsetInFile] + lc.cmdsize - sizeof(lc)];
        }
    }

    return nil;
}

-(NSString*)codeHash {
    NSMutableString* prehashedString = [NSMutableString new];
    
    NSArray* sortedSlices = [_slices sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [[obj1 architectureName] compare:[obj2 architectureName]];
    }];
    
    for (FIRAppDistributionMachOSlice* slice in sortedSlices) {
        [prehashedString appendString:[slice uuidString]];
    }

    return [self sha1:prehashedString];;
}

-(NSString*)sha1:(NSString*)prehashedString {
    NSData *data = [prehashedString dataUsingEncoding:NSUTF8StringEncoding];
     uint8_t digest[CC_SHA1_DIGEST_LENGTH];
     CC_SHA1(data.bytes, (int)data.length, digest);
     NSMutableString *hashedString = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
     for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
         [hashedString appendFormat:@"%02x", digest[i]];
    
    return hashedString;
}
@end
