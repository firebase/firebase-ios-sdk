// Copyright 2023 Google LLC
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

import ArgumentParser
import Foundation

struct PrivacyManifestGenerator: ParsableCommand {
  @Argument(
    help: ArgumentHelp("The xcframework to create the Privacy Manifest for."),
    transform: URL.init(fileURLWithPath:)
  )
  var xcframework: URL

  func validate() throws {
    guard xcframework.pathExtension == "xcframework" else {
      throw ValidationError("Given path does not end in `.xcframework`: \(xcframework.path)")
    }
  }

  func run() throws {
    let wizard = PrivacyManifestWizard.makeWizard(xcframework: xcframework)

    while let question = wizard.nextQuestion() {
      print(question)
      if let answer = readLine() {
        try wizard.processAnswer(answer)
      }
    }

    let privacyManifest = try wizard.createManifest()
    print(privacyManifest)
  }
}
