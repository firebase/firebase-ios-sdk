// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import MachO

@objc(FIRCLSEntitlementsReader)
public class EntitlementsReader: NSObject {
  private struct CSMultiBlob {
    var magic: UInt32
    var lentgh: UInt32
    var count: UInt32
  }

  private struct CSBlob {
    var type: UInt32
    var offset: UInt32
  }

  private enum CSMagic {
    static let embeddedSignature: UInt32 = 0xFADE_0CC0
    static let embededEntitlements: UInt32 = 0xFADE_7171
  }

  @objc public func readEntitlements() -> Entitlements? {
    var executableHeader: UnsafePointer<mach_header>? = nil

    for i in 0 ..< _dyld_image_count() {
      let imageHeader = _dyld_get_image_header(i)

      if let filetype = imageHeader?.pointee.filetype, filetype == MH_EXECUTE {
        executableHeader = imageHeader
        break
      }
    }

    guard let executableHeader = executableHeader else {
      print("Application image not found")
      return nil
    }

    let is64bit = executableHeader.pointee.magic == MH_MAGIC_64 || executableHeader.pointee
      .magic == MH_CIGAM_64

    var curLoadCommandIterator = Int(bitPattern: executableHeader) +
      (is64bit ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size)

    for _ in 0 ..< executableHeader.pointee.ncmds {
      guard let segmentCommand = UnsafePointer<segment_command>(
        bitPattern: curLoadCommandIterator
      )?.pointee else {
        return nil
      }

      if segmentCommand.cmd == LC_CODE_SIGNATURE {
        break
      }
      curLoadCommandIterator = curLoadCommandIterator + Int(segmentCommand.cmdsize)
    }

    guard let dataCommand =
      UnsafePointer<linkedit_data_command>(bitPattern: curLoadCommandIterator)?.pointee else {
      return nil
    }

    let dataStart = Int(bitPattern: executableHeader) + Int(dataCommand.dataoff)

    var signatureCursor: Int = dataStart

    // This segement is not always has signature start
    // When I test on debug build the this segment also contains symbol table
    // need to iterate addresses and find the magic first
    while signatureCursor < dataStart + Int(dataCommand.datasize) {
      guard let multiBlob = UnsafePointer<CSMultiBlob>(bitPattern: signatureCursor)?.pointee else {
        return nil
      }
      print(String(format: "Finding Magic Number: 0x%08X", CFSwapInt32(multiBlob.magic)))
      if CFSwapInt32(multiBlob.magic) == CSMagic.embeddedSignature {
        return readEntitlementsFromSignature(startingAt: signatureCursor, multiBlob: multiBlob)
      }
      signatureCursor = signatureCursor + 4
    }

    print("Cannot find the magic number")
    return nil
  }

  private func readEntitlementsFromSignature(startingAt offset: Int,
                                             multiBlob: CSMultiBlob) -> Entitlements? {
    let multiBlobSize = MemoryLayout<CSMultiBlob>.size
    let blobSize = MemoryLayout<CSBlob>.size
    let itemCount = Int(CFSwapInt32(multiBlob.count))

    for index in 0 ..< itemCount {
      let blobOffset = offset + multiBlobSize + index * blobSize
      let blob = UnsafePointer<CSBlob>(bitPattern: blobOffset)?.pointee
      // the first 4 bytes are the magic
      // the next 4 are the length
      // after that is the encoded plist
      if
        let blob = UnsafePointer<CSBlob>(bitPattern: blobOffset)?.pointee,
        let magic = UnsafePointer<UInt32>(bitPattern: offset + Int(CFSwapInt32(blob.offset)))?
        .pointee, CFSwapInt32(magic) == CSMagic.embededEntitlements {
        if let signatureLength =
          UnsafePointer<UInt32>(bitPattern: offset + Int(CFSwapInt32(blob.offset)) + 4)?.pointee,
          let entitlementDataPointer =
          UnsafeRawPointer(bitPattern: offset + Int(CFSwapInt32(blob.offset)) + 8) {
          let data = Data(
            bytes: entitlementDataPointer,
            count: Int(CFSwapInt32(signatureLength)) - 8
          )

          guard let rawValues = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
          ) as? [String: Any] else {
            return nil
          }
          return Entitlements(rawValue: rawValues)
        }
      }
    }
    return nil
  }
}
