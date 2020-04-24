import Foundation

import ShellUtils

class CocoapodsReader: PackageReader {
  func packagesInDirectory(_ dirURL: URL) throws -> [PackageData] {

    return try podspecURLs(at: dirURL).map { (podspecURL) -> PackageData in
      print("podspecURL: \(podspecURL)")
      return PackageData.undefined()
    }
  }

  private func podspecURLs(at dirURL: URL) throws -> [URL] {
    return try FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [])
      .filter { (itemURL) -> Bool in
        return itemURL.pathExtension == "podspec"
    }

  }
  
}
