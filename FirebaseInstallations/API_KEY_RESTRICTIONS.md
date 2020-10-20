# API-Key restrictions may need to be updated with new version of Firebase iOS SDKs.

## What happened?

The following SDKs updates introduce a dependency on the [Firebase Installations API](https://console.cloud.google.com/apis/library/firebaseinstallations.googleapis.com), a new infrastructure service for Firebase:

- Analytics
- Cloud Messaging
- Remote Config
- In-App Messaging
- A/B Testing
- Performance Monitoring
- ML Kit
- Instance ID


As a result, API restrictions you may have applied to API keys used by your Firebase applications may have to be updated to allow your apps to call the Firebase Installations API.

## What do I need to do?

Before upgrading your application(s) to the latest SDK version, please **make sure that the API key(s) used in your application(s) are added to the allowlist for the Firebase Installations API:**

- **Open** the [Google Cloud Platform Console](https://console.cloud.google.com/apis/credentials?folder).
- **Choose** the project you use for your application(s).
- **Open**  `APIs & Services` and **select** `Credentials`.
- **Click** `Edit API Key` (pencil icon) for the API key in question.
- **Scroll down** to the `API restrictions` section.
- If the radio button shows `Don't restrict key`, the API key is not affected.
Otherwise, from the dropdown menu, **add** the `Firebase Installations API` to the list of permitted APIs, and click `Save`.
