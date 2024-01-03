# Firebase Dynamic Links SDK for iOS

> [!IMPORTANT]
> Firebase Dynamic Links is **deprecated** and should not be used in new projects. The service will shut down on August 25, 2025.
>
> Please see our [Dynamic Links Deprecation FAQ documentation](https://firebase.google.com/support/dynamic-links-faq) for more guidance.

Firebase Dynamic Links are universal deep links that persist across app installs.
For more info, see the [Firebase website](https://firebase.google.com/products/dynamic-links).

Please visit [our developer site](https://firebase.google.com/docs/dynamic-links/) for integration
instructions, documentations, support information, and terms of service.

## Managing the Pasteboard

Firebase Dynamic Links 4.2.0 and higher use a plist property
`FirebaseDeepLinkPasteboardRetrievalEnabled` that a developer can set to enable/disable the use of
iOS pasteboard by the SDK.

FDL SDK uses the pasteboard for deep-linking post app install (to enable deferred deep-linking,
where the link is copied on the
[app preview page](https://firebase.google.com/docs/dynamic-links/link-previews#app_preview_pages))
and app install attribution; otherwise, FDL does not use the pasteboard for anything else.

Disabling pasteboard access affects the app in the following ways:
* Deferred deep-linking will not work as reliably.  At best, your app receives
[weak matches](https://firebase.google.com/docs/reference/unity/namespace/firebase/dynamic-links#linkmatchstrength)
for deep-links.
* App install attribution stats will be less accurate (potentially undercounting app installs).

Enabling pasteboard access affects the app in the following ways:
* On iOS 14, will show a system alert notifying that your app accessed the content in the
pasteboard. This should happen one-time after installation of the app.
* Deferred deep-linking will work as designed.  At best, your app receives a
[perfect match](https://firebase.google.com/docs/reference/unity/namespace/firebase/dynamic-links#linkmatchstrength)
for deep-links.
* SDK will be able to more reliably attribute installation stats for links.

For more information, check out the
[iOS documentation](https://firebase.google.com/docs/dynamic-links/ios/receive).
