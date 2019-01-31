import Foundation
import Utility

// Get the launch arguments, parsed by user defaults.
let args = LaunchArgs()

// Clear the cache if requested.
if args.deleteCache {
  do {
    let cacheDir = try FileManager.default.firebaseCacheDirectory()
    try FileManager.default.removeItem(at: cacheDir)
  } catch {
    fatalError("Could not empty the cache before building the zip file: \(error)")
  }
}

// Keep timing for how long it takes to build the zip file for information purposes.
let buildStart = Date()
var cocoaPodsUpdateMessage: String = ""

// Do a Pod Update if requested.
if args.updatePodRepo {
  CocoaPodUtils.updateRepos()
  cocoaPodsUpdateMessage = "CocoaPods took \(-buildStart.timeIntervalSinceNow) seconds to update."
}

var paths = ZipBuilder.FilesystemPaths(templateDir: args.templateDir,
                                       coreDiagnosticsDir: args.coreDiagnosticsDir)
paths.allSDKsPath = args.allSDKsPath
paths.currentReleasePath = args.currentReleasePath
let builder = ZipBuilder(paths: paths,
                         customSpecRepos: args.customSpecRepos,
                         useCache: args.cacheEnabled)

do {
  // Build the zip file and get the path.
  let location = try builder.buildAndAssembleZipDir()

  // Get the time since the start of the build to get the full time.
  let secondsSinceStart = -Int(buildStart.timeIntervalSinceNow)
  print("""
    Time profile:
      It took \(secondsSinceStart) seconds (~\(secondsSinceStart / 60)m) to build the zip file.
      \(cocoaPodsUpdateMessage)
    """)

  print("Location of zip file: \(location)")
} catch let error {
  let secondsSinceStart = -buildStart.timeIntervalSinceNow
  print("""
    Time profile:
      The build failed in \(secondsSinceStart) seconds (~\(secondsSinceStart / 60)m).
      \(cocoaPodsUpdateMessage)
    """)
  fatalError("Could not build the zip file: \(error)")
}
