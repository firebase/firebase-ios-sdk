#!/usr/bin/env xcrun swift

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

import Foundation

enum Colors: String {
  case black = "\u{001B}[0;30m"
  case red = "\u{001B}[0;31m"
  case green = "\u{001B}[0;32m"
  case yellow = "\u{001B}[0;33m"
  case blue = "\u{001B}[0;34m"
  case magenta = "\u{001B}[0;35m"
  case cyan = "\u{001B}[0;36m"
  case white = "\u{001B}[0;37m"
}

func colorPrint(color: Colors, text: String) {
  print(color.rawValue + text + "\u{001B}[0;0m")
}

enum Platform: String {
  case iOS
  case macOS
  case tvOS
  case watchOS
}

let allFrameworks: [String: [Platform]] = [
  "FirebaseAuth": [.iOS, .macOS],
  "FirebaseCore": [.iOS, .macOS],
  "FirebaseDatabase": [.iOS, .macOS],
  "FirebaseMessaging": [.iOS],
  "FirebaseStorage": [.iOS, .macOS]
]

let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let url = URL(fileURLWithPath: CommandLine.arguments[0], relativeTo: currentDirectoryURL)
let commandPath = url.deletingLastPathComponent().path

func usage() -> Never {
  print("usage: ./build.swift -f {framework1} -f {framework2} ....")
  print("usage: ./build.swift -all")
  print("Valid frameworks are \(allFrameworks)")
  exit(1)
}

func processOptions() -> [String] {
  guard CommandLine.arguments.count > 1 else {
    usage()
  }
  var doFrameworks = [String]()
  var optIndex = 1
  whileLoop: while optIndex < CommandLine.arguments.count {
    switch CommandLine.arguments[optIndex] {
    case "-all":
      guard doFrameworks.count == 0, CommandLine.arguments.count == 2 else {
        colorPrint(color:Colors.red, text:"-all must be a solo option")
        usage()
      }
      doFrameworks = Array(allFrameworks.keys)
      break whileLoop
    case "-f":
      optIndex += 1
      guard optIndex < CommandLine.arguments.count else {
        colorPrint(color:Colors.red, text:"The -f option must be followed by a framework name")
        usage()
      }
      let framework = CommandLine.arguments[optIndex]
      guard allFrameworks.keys.contains(framework) else {
        colorPrint(color:Colors.red, text:"\(framework) is not a valid framework")
        usage()
      }
      doFrameworks += [framework]
      optIndex += 1
    default:
      colorPrint(color:Colors.red, text: "Invalid option: \(CommandLine.arguments[optIndex])")
      usage()
    }
  }
  return doFrameworks
}

func tempDir() -> String {
  let directory = NSTemporaryDirectory()
  let fileName = NSUUID().uuidString
  guard let dir = NSURL.fileURL(withPathComponents:[directory, fileName]) else {
    colorPrint(color:Colors.red, text:"Failed to create temp directory")
    exit(1)
  }
  return dir.path
}

func syncExec(command: String, args: [String] = []) {
  let task = Process()
  task.launchPath = command
  task.arguments = args
  task.currentDirectoryPath = commandPath
  task.launch()
  task.waitUntilExit()
  guard (task.terminationStatus == 0) else {
    colorPrint(color:Colors.red, text:"Command failed:")
    colorPrint(color:Colors.red, text:command + " " + args.joined(separator:" "))
    exit(1)
  }
}

func buildThin(framework: String, multiplatform: Bool, arch: String, multisdk: Bool, sdk: String, parentDir: String) -> [String] {
  let schemeSuffix: String
  if !multiplatform {
    schemeSuffix = ""
  } else if sdk.hasPrefix("mac") {
    schemeSuffix = "-macOS"
  } else if sdk.hasPrefix("iphone") {
    schemeSuffix = "-iOS"
  } else {
    fatalError("TODO: tvOS/watchOS")
  }

  let buildDir = parentDir + "/" + arch
  let standardOptions = [ "build",
                          "-configuration", "release",
                          "-workspace", "FrameworkMaker.xcworkspace",
                          "-scheme", framework + schemeSuffix,
                          "GCC_GENERATE_DEBUGGING_SYMBOLS=No"]
  let bitcode = (sdk == "iphoneos") ? ["OTHER_CFLAGS=\"" + "-fembed-bitcode\""] : []
  let args = standardOptions + ["ARCHS=" + arch, "BUILD_DIR=" + buildDir, "-sdk", sdk] + bitcode
  syncExec(command:"/usr/bin/xcodebuild", args:args)
  return [buildDir + "/Release" + (multisdk ? "-\(sdk)" : "") + "/" + framework + schemeSuffix + "/lib" + framework + schemeSuffix + ".a"]
}

func createFile(file: String, content: String) {
  let data = content.data(using:String.Encoding.utf8)
  guard FileManager.default.createFile(atPath:file, contents: data, attributes: nil) else {
    print("Error creating " + file)
    exit(1)
  }
}

// TODO: Add support for adding library and framework dependencies to makeModuleMap
func makeModuleMap(framework: String, dir: String) {
  let moduleDir = dir + "/Modules"
  syncExec(command:"/bin/mkdir", args:["-p", moduleDir])
  let moduleFile = moduleDir + "/module.modulemap"
  let content = "framework module " + framework + " {\n" +
    "  umbrella header \"" + framework + ".h\"\n" +
    "  export *\n" +
    "  module * { export *}\n" +
    "}\n"
  createFile(file:moduleFile, content:content)
}

func buildFramework(withName framework: String, multiplatform: Bool, platform: Platform, outputDir: String) {
  let buildDir = tempDir()
  var thinArchives = [String]()
  switch platform {
  case .iOS:
    thinArchives += buildThin(framework:framework, multiplatform: multiplatform, arch:"arm64", multisdk: true, sdk:"iphoneos", parentDir:buildDir)
    thinArchives += buildThin(framework:framework, multiplatform: multiplatform, arch:"armv7", multisdk: true, sdk:"iphoneos", parentDir:buildDir)
    thinArchives += buildThin(framework:framework, multiplatform: multiplatform, arch:"i386", multisdk: true, sdk:"iphonesimulator", parentDir:buildDir)
    thinArchives += buildThin(framework:framework, multiplatform: multiplatform, arch:"x86_64", multisdk: true, sdk:"iphonesimulator", parentDir:buildDir)
  case .macOS:
    thinArchives += buildThin(framework:framework, multiplatform: multiplatform, arch:"x86_64", multisdk: false, sdk:"macosx", parentDir:buildDir)
  default: fatalError("TODO: tvOS/watchOS")
  }

  let frameworkDir = outputDir + "/" + framework + "_" + platform.rawValue + ".framework"
  syncExec(command:"/bin/mkdir", args:["-p", frameworkDir])
  let fatArchive = frameworkDir + "/" + framework
  syncExec(command:"/usr/bin/lipo", args:["-create", "-output", fatArchive] + thinArchives)
  syncExec(command:"/bin/rm", args:["-rf"] + thinArchives)
  let headersDir = frameworkDir + "/Headers"
  syncExec(command:"/bin/mv", args:[NSString(string:thinArchives[0]).deletingLastPathComponent, headersDir])
  syncExec(command:"/bin/rm", args:["-rf", buildDir])
  makeModuleMap(framework:framework, dir:frameworkDir)
}

let frameworks = processOptions()
colorPrint(color:Colors.green, text:"Building \(frameworks)")

let outputDir = tempDir()

syncExec(command:"/usr/local/bin/pod", args:["update"])

for f in frameworks {
  let platforms = allFrameworks[f]!
  for p in platforms {
    buildFramework(withName:f, multiplatform:platforms.count > 1, platform:p, outputDir:outputDir)
  }
}

print()
colorPrint(color:Colors.magenta, text:"The frameworks are available at the locations below:")
syncExec(command:"/usr/bin/find", args:[outputDir, "-depth", "1"])
