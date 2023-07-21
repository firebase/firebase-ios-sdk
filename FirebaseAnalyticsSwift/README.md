# Firebase Analytics Swift SDK

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
Sure! Let's create an example that demonstrates how the custom event logging API and manual screen view event logging API can make the code more efficient and reduce the number of lines required for event logging.

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
                // Using the new custom event logging API to log the button click.
                Analytics.logCustomEvent(name: "button_clicked")
            }
        }
        // Using the new manual screen view event logging API to log the screen view.
        .analyticsScreen(name: "main_content")
    }
}

// Introducing a custom event logging API.
extension Analytics {
    static func logCustomEvent(name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
}

// Introducing a manual screen view event logging API.
extension View {
    func analyticsScreen(name: String, class screenClass: String? = nil, extraParameters: [String: Any]? = nil) -> some View {
        onAppear {
            var params: [String: Any] = [AnalyticsParameterScreenName: name]
            if let screenClass = screenClass {
                params[AnalyticsParameterScreenClass] = screenClass
            }
            if let extraParams = extraParameters {
                params.merge(extraParams) { _, new in new }
            }
            Analytics.logEvent(AnalyticsEventScreenView, parameters: params)
        }
    }
}
```

In this example, using the custom event logging API and manual screen view event logging API significantly reduces the amount of code required for event logging:

1. Before: We had separate event logging code for both the button click and screen view events, resulting in redundant lines of code.
2. After: With the custom event logging API and manual screen view event logging API, we have reduced the event logging code to a few lines, improving code efficiency and readability.

By using these APIs, you can easily log events and screen views throughout the app with concise and reusable code, making it more efficient and maintainable.



