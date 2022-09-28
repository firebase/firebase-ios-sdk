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




