#!/usr/bin/xcrun swift

import Foundation

@discardableResult
func shell(_ args: String...) -> Int32 {
  let task = Process()
  task.launchPath = "usr/bin/env"
  task.arguments = ["bash", "-c"] + args
  task.launch()
  task.waitUntilExit()
  return task.terminationStatus
}

let jazzyCheck = shell("jazzy --version")
guard jazzyCheck == 0 else {
  exit(jazzyCheck)
}
