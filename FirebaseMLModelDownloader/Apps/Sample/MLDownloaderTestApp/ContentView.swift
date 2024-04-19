// Copyright 2020 Google LLC
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

import FirebaseMLModelDownloader
import SwiftUI

struct ContentView: View {
  var downloadTotal: Float = 1.0
  @ObservedObject var downloader = Downloader()

  private var buttons: some View {
    VStack(spacing: 10) {
      Button(action: downloader.downloadModelHelper(downloadType: .localModel), label: {
        Text("Local Model")
      })
      .buttonStyle(CustomDownloadButtonStyle())

      Button(
        action: downloader.downloadModelHelper(downloadType: .localModelUpdateInBackground),
        label: {
          Text("Local Model (Background Update)")
        }
      )
      .buttonStyle(CustomDownloadButtonStyle())

      Button(action: downloader.downloadModelHelper(downloadType: .latestModel), label: {
        Text("Latest Model")
      })
      .buttonStyle(CustomDownloadButtonStyle())

      Button(action: downloader.listModelHelper(), label: {
        Text("List Models")
      })
      .buttonStyle(CustomListButtonStyle())
      .padding()

      Button(action: downloader.deleteModelHelper(), label: {
        Text("Delete Model")
      })
      .buttonStyle(CustomDeleteButtonStyle())
    }
  }

  private var download: some View {
    VStack {
      if downloader.downloadProgress >= downloadTotal {
        Text("Model downloaded!")
          .foregroundColor(.green)
      } else {
        Text("Model already on device!")
          .foregroundColor(.green)
      }
      Text("Model saved at \(downloader.filePath).")
        .foregroundColor(.gray)
        .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
        .font(.footnote)
    }
  }

  private var delete: some View {
    Text("Model deleted.")
      .foregroundColor(.purple)
      .padding()
  }

  private var list: some View {
    VStack {
      Text("These models are currently on device.")
        .foregroundColor(.green)
      List(downloader.modelNames, id: \.self) { name in
        Text(name)
          .foregroundColor(.pink)
          .padding()
      }
    }
  }

  var body: some View {
    VStack(spacing: 10) {
      Text("Download Model")
        .font(.title)

      TextField("Enter model name", text: $downloader.modelName)
        .frame(width: 200, height: 100)
        .clipped()
        .autocapitalization(.none)
        .textFieldStyle(RoundedBorderTextFieldStyle())

      buttons

      ProgressView("Downloading...", value: downloader.downloadProgress, total: downloadTotal)
        .progressViewStyle(CustomProgressViewStyle(progress: downloader.downloadProgress,
                                                   total: downloadTotal))

      if downloader.isDownloaded {
        download
      }

      if downloader.isDeleted {
        delete
      }

      if downloader.modelNames.count > 0 {
        list
      }

      if downloader.isError {
        Text(downloader.error)
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}

struct CustomProgressViewStyle: ProgressViewStyle {
  var downloadProgressColor: Color = .blue
  var downloadCompletecolor: Color = .green
  var progress: Float
  var total: Float

  func makeBody(configuration: Configuration) -> some View {
    ProgressView(configuration)
      .padding(.horizontal, 30)
      .opacity(progress > 0 && progress < total ? 0.8 : 0.0)
  }
}

struct CustomDownloadButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(5)
      .foregroundColor(.white)
      .background(configuration.isPressed ? Color.orange : Color.blue)
      .shadow(radius: 5)
  }
}

struct CustomListButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(5)
      .foregroundColor(.white)
      .background(configuration.isPressed ? Color.orange : Color.green)
      .shadow(radius: 5)
  }
}

struct CustomDeleteButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(5)
      .foregroundColor(.white)
      .background(configuration.isPressed ? Color.orange : Color.red)
      .shadow(radius: 5)
  }
}
