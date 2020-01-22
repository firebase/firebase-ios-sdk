# 2020-01-28 -- v0.16.0
- [changed] Consolidated backend and UI SDKs under `FirebaseInAppMessaging`. Developers should now use `pod Firebase/InAppMessaging` in their Podfile.
- [changed] `FIRIAMDefaultDisplayImpl` is no longer public.
- [changed] `FirebaseInAppMessagingDisplay` is now deprecated and should be removed from developers' Podfiles.
- [changed] Minimum iOS version is now 9.0.

# 2019-12-17 -- v0.15.6
- [fixed] Issues with nullability in card message (#4435).
- [fixed] Unit test failure with OCMock 3.5.0 (#4420).
- [fixed] Crash in test on device error flow (#4446).

# 2019-10-08 -- v0.15.5
- [added] Added support for UIScene based application lifecycle (#3927).

# 2019-09-03 -- v0.15.4
- [fixed] Undeprecated initializer for FIRInAppMessagingAction so it can be used going forward in custom UI display (#3545).

# 2019-07-23 -- v0.15.2
- [fixed] Fixed issue with messages to be triggered on app launch (#3237).

# 2019-06-04 -- v0.15.0
- [added] Added support for card in-app messages (#2947).
- [added] Added direct triggering (via FIAM SDK) of in-app messages (#3081).

# 2019-05-21 -- v0.14.1
- [fixed] Fixed an issue with messages not showing up from custom analytics event trigger (#2981).
- [fixed] Fixed crash from sending analytics events with no instance ID (#2988).

# 2019-03-05 -- v0.13.0
- [added] Added a feature allowing developers to programmatically register a delegate for updates on in-app engagement (impression, click, display errors).

# 2018-09-25 -- v0.12.0
- [changed] Separated UI functionality into a new open source SDK called FirebaseInAppMessagingDisplay.
- [fixed] Respect fetch between wait time returned from API responses.

# 2018-08-15 -- v0.11.0
- First Beta Release.
