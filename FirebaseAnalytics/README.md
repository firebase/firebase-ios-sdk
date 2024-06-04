# Firebase Analytics SDK

Introduce a manual screen view event logging API that enable developers to log individual views in SwiftUI lifecycle.

## Code Samples

### Before
```swift

struct ContentView: View {
  var body: some View {
    Text("Hello, world!")
      // Logging screen name with class and a custom parameter.
      .onAppear {
        Analytics.logEvent(AnalyticsEventScreenView,
                           parameters: [AnalyticsParameterScreenName: "main_content",
                                        AnalyticsParameterScreenClass: "ContentView",
                                        "my_custom_param": 5])
      }

       // OR Logging screen name only.
      .onAppear {
        Analytics.logEvent(AnalyticsEventScreenView,
                           parameters: [AnalyticsParameterScreenName: "main_content"])
      }
  }
}

```

### After
```swift
struct ContentView: View {
  var body: some View {
    Text("Hello, world!")
       // Logging screen name with class and a custom parameter.
      .analyticsScreen(name: "main_content",
                       class: "ContentView",
                       extraParameters: ["my_custom_param": 5])

      // OR Logging screen name only, class and extra parameters are optional.
      .analyticsScreen(name: "main_content")
  }
}
```
An example that demonstrates how the custom event logging API and manual screen view event logging API can make the code more efficient and reduce the number of lines required for event logging.

### Before (Without APIs)

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            Text("Welcome to our App!")
                .padding()
            Button("Click Me!") {
                // Logging a custom event when the button is clicked.
                Analytics.logEvent("button_clicked", parameters: nil)
            }
        }
        .onAppear {
            // Logging the screen view event when the ContentView appears.
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "main_content"])
        }
    }
}
```

### After (With APIs)

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            Text("Welcome to our App!")
                .padding()
            Button("Click Me!") {
                // Directly using Firebase's logEvent method to log the button click.
                Analytics.logEvent("button_clicked", parameters: nil)
            }
        }
        // Using the new manual screen view event logging API to log the screen view.
        .analyticsScreen(name: "main_content")
    }
}


// Introducing a manual screen view event logging API.
extension View {
    func analyticsScreen(name: String, class screenClass: String? = nil, extraParameters: [String: Any]? = nil) -> some View {
        onAppear {
            var params: [String: Any] = [AnalyticsParameterScreenName: name]
            if let screenClass {
                params[AnalyticsParameterScreenClass] = screenClass
            }
            if let extraParameters {
                params.merge(extraParameters) { _, new in new }
            }
            Analytics.logEvent(AnalyticsEventScreenView, parameters: params)
        }
    }
}
```

In this example, by leveraging the custom event logging API and manual screen view event logging API, we achieve a significant reduction in code complexity for event tracking:

1. **Before:** In the previous implementation, event logging for button clicks and screen views required separate blocks of code, leading to redundant lines of code throughout the
app. This redundancy made the codebase less efficient and harder to maintain.

2. **After:** By adopting the event logging API and manual screen view event logging API, we now condense the event tracking logic into just a few lines of code. This streamlined
approach improves the overall code efficiency and enhances code readability.
