# Using Firebase from a Framework or a library

Currently all source code and binary Firebase SDKs are compiled as **static**
frameworks. It may be not too important detail if Firebase SDKs are used from an
app target directly, but must be taken into account if Firebase is used from
another library or a framework. The key difference is in the way static and
dynamic linking works. Your framework itself may be either static or dynamic.
Let's consider these two options in more details.

## Using Firebase SDKs from dynamic framework

When a dynamic framework/library is compiled, each static dependency symbols are
added to the dynamic framework binary. It is not really important unless you
need to use both the dynamic framework and one of its static dependencies
directly in your app or another framework. In this case if you attempt to link
the same static framework/library to both the app and the dynamic framework you
will end up with the static framework symbols added to both the app and the
dynamic framework binaries. It means that when you app launches it will have two
copy of the static framework symbols. This leads to undefined behavior
(especially when different versions of the static framework are linking to the
app and the dynamic framework). For example, a `dispatch_once` may or may not do
the right initialization since there are now two entities to initialize. Here
are couple more examples of issues related to this undefined behavior:
[#4315](https://github.com/firebase/firebase-ios-sdk/issues/4315),
[#5152](https://github.com/firebase/firebase-ios-sdk/issues/4315), etc.

In this case you will most likely see warnings like the following in the
console:

```text
objc[40943]: Class FIRApp is implemented in both
~/Library/Developer/Xcode/DerivedData/FrameworkTest-apqjxlyrxvkbhhafhaypsbdquref/Build/Products/Debug-iphonesimulator/DynamicFramework.framework/DynamicFramework
(0x10b2a87f8) and
~/Library/Developer/CoreSimulator/Devices/4821F959-24A6-4D78-A102-4C5703103D99/data/Containers/Bundle/Application/F017D210-113A-4DAF-9E17-BDE455E71E06/FrameworkTest.app/FrameworkTest
(0x10ad2d348). One of the two will be used. Which one is undefined.
```

See also
[Using dynamic framework which is linked with static framework](https://forums.developer.apple.com/thread/105062#319818).

<img src="./resources/firebase_from_dynamic_framework.svg" width=500/>
**Using Firebase SDKs from dynamic framework**

**Conclusions:**

-   Firebase may be used from an embedded dynamic framework in your project
    (e.g. for the code reuse purposes) only when Firebase is not used from the
    app directly.
-   Firebase SDKs should never be used from vendor dynamic frameworks because
    the version of Firebase compiled into the dynamic framework will early or
    later conflict with the customer Firebase version.

## Using Firebase SDKs from static framework/library

When a static framework/library is compiled it is not required to add any static
or dynamic dependencies to the binary because presence of the dependencies will
be done when the app binary is compiled. It means that both the static
framework/library and your app will be able to "share" the dependency symbols
(which is basically what we need).

The main downside of this approach arises when the static framework using
Firebase is used from e.g. an app and its extension. In this case, in contrast
to a dynamic embedded framework, a copy of the static framework will be added to
both the app and each extension. It doesn't lead to any symbol collisions, but
it leads to increasing the download size of your app.

<img src="./resources/firebase_from_static_framework.svg" width=700>Using Firebase SDKs from static framework</img>

**Conclusions:**

-   Firebase SDKs in static frameworks/libraries is safe for both vendor and
    in-app internal libraries
-   if the static framework is used from an app and its extensions, then it will
    be copied to each target increasing the app download size
