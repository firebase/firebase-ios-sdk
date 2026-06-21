
# Firebase Swift Sample App

This Sample App is used for manual and automated Firebase Auth integration testing.

It's implementation is based on the quickstart that can be found
[here](https://github.com/firebase/quickstart-ios/tree/main/authentication)

## Getting Started

Firebase Auth offers multiple ways to authenticate users. In this sample, we demonstrate how you can use Firebase Auth to authenticate users by providing implementations for the various authentication flows. Since each Firebase Auth flow is different, each may require a few extra steps to set everything up. Feel free to follow along and configure as many authentication flows as you would like to demo!

Ready? Let's get started! 🏎💨

Open the `AuthenticationExample.xcodeproj` project.

## Connecting to the [Firebase Console](https://console.firebase.google.com)

We will need to connect our sample with the [Firebase Console](https://console.firebase.google.com). For an in depth explanation, you can read more about [adding Firebase to your iOS Project](https://firebase.google.com/docs/ios/setup).

### Here's a summary of the steps!
1. Visit the [Firebase Console](https://console.firebase.google.com) and create a new app.
2. Add an iOS app to the project. Make sure the `Bundle Identifier` you set for this iOS App matches that of the one in this sample.
3. Download the `GoogleService-Info.plist` when prompted.
4. Drag the downloaded `GoogleService-Info.plist` into the opened app. In Xcode, you can also add this file to the project by going to `File`-> `Add Files to 'AuthenticationExample'` and selecting the downloaded `.plist` file. Be sure to add the `.plist` file to the app's main target.
5. At this point, you can build and run the sample! 🎉


## Configuring Identity Providers

To enable sign in with each of the following identity providers, there are a few configuration steps required to make sure everything works properly.

**When it comes to configuring most of the below identity providers**, you may have to [add a custom URL scheme](https://developers.google.com/identity/sign-in/ios/start-integrating#add_a_url_scheme_to_your_project) in your Xcode project so Firebase Auth can correctly work with the corresponding Identity Provider. This is done by selecting the app's target in Xcode and navigating to the **Info** tab. For each login flow that requires adding a custom URL scheme, be sure to add a new URL Scheme for each respective identity provider rather than replace existing schemes you have created previously.


### Google Sign In

We have already included the **`GoogleSignIn`** cocoapod in the `Podfile`. This cocoapod is **required** for **Google Sign In**.

#### Start by going to the [Firebase Console](https://console.firebase.google.com) and navigate to your project:

- Select the **Auth** panel and then click the **Sign In Method** tab.

- Click **Google** and turn on the **Enable** switch, then click **Save**.

- In Xcode, [add a custom URL scheme for your reversed client ID](https://developers.google.com/identity/sign-in/ios/start-integrating#add_a_url_scheme_to_your_project).
    - You can find this in the `GoogleService-Info.plist`. This is the value associated with the **`REVERSED_CLIENT_ID`** key in the  `GoogleService-Info.plist` file.
    - For the `URL Type`'s **Identifier**, something like "Firebase Auth" adds some context for what the reversed link is related to.
    - In Xcode, select the target and navigate to the `Info` tab. Look for the `URL Types` section. Expand the section and add a 'URL Type' and by pasting in the URL and, optionally, adding an identifier.

- Run the app on your device or simulator.

- Choose **Google** under **Identity Providers** to launch the **Google Sign In** flow

- See the [Getting Started with Google Sign In guide](https://firebase.google.com/docs/auth/ios/google-signin) for more details.


### Sign in with Apple

As outlined in the docs, **Sign in with Apple** requires enabling the *Sign In with Apple* [`Capability`](https://developer.apple.com/documentation/xcode/adding_capabilities_to_your_app) in the Xcode project.

#### Start by going to the [Firebase Console](https://console.firebase.google.com) and navigate to your project:

- Select the **Auth** panel and then click the **Sign In Method** tab.
- Click **Apple** and turn on the **Enable** switch, then click **Save**.
- Run the app on your device or simulator.
- Choose **Apple** under **Identity Providers** to launch the **Sign in with Apple** flow
- See the [Getting Started with Apple Sign In guide](https://firebase.google.com/docs/auth/ios/apple) for more details.


### Twitter
#### Start by going to the [Firebase Console](https://console.firebase.google.com) and navigate to your project:
  - Select the **Auth** panel and then click the **Sign In Method** tab.
  - Click **Twitter** and turn on the **Enable** switch, then click **Save**.
  - You'll need to register an app on Twitter's [developer portal](https://apps.twitter.com) to obtain the **API Key** and **App Secret**.
  - After registering an app on Twitter's developer portal, enter your Twitter **API Key** and **App Secret** and then click **Save**.
  - Make sure your Firebase OAuth redirect URI (e.g. my-app-12345.firebaseapp.com/__/auth/handler) is set as your
    Authorization callback URL in your app's settings page on your [Twitter app's config](https://apps.twitter.com).
   - In Xcode, [add a custom URL scheme for your reversed client ID](https://developers.google.com/identity/sign-in/ios/start-integrating#add_a_url_scheme_to_your_project).
        - Note that you may have already done this previously
        - You can find this in the  `GoogleService-Info.plist`
- Run the app on your device or simulator.
- Choose **Twitter** under **Identity Providers** to launch the **Twitter Sign In** flow

- See the [Getting Started with Twitter Sign In guide](https://firebase.google.com/docs/auth/ios/twitter-login) for more details.

### Microsoft
#### Start by going to the [Firebase Console](https://console.firebase.google.com) and navigate to your project:
- Select the **Auth** panel and then click the **Sign In Method** tab.
  - Click **Microsoft** and turn on the **Enable** switch, then click **Save**.
  - You'll need to register an app on Microsoft's [developer portal](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-v2-register-an-app) to obtain the **Application Id** and **Application Secret**.
  - After registering an app on Microsoft's developer portal, enter your Microsoft **Application Id** and **Application Secret** and then click **Save**.
  - Make sure your Firebase OAuth redirect URI (e.g. my-app-12345.firebaseapp.com/__/auth/handler) is set as your
    Authorization callback URL in your app's settings page on your [Microsoft app's config](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-v2-register-an-app).
- In Xcode, [add a custom URL scheme for your reversed client ID](https://developers.google.com/identity/sign-in/ios/start-integrating#add_a_url_scheme_to_your_project).
  - Note that you may have already done this in a previous step
  - You can find this in the `GoogleService-Info.plist`
- Run the app on your device or simulator.
- Choose **Microsoft** under **Identity Providers** to launch the **Microsoft Sign In** flow

See the [Getting Started with Microsoft Sign In guide](https://firebase.google.com/docs/auth/ios/microsoft-oauth) for more details.

### GitHub
#### Start by going to the [Firebase Console](https://console.firebase.google.com) and navigate to your project:
- Select the **Auth** panel and then click the **Sign In Method** tab.
  - Click **GitHub** and turn on the **Enable** switch, then click **Save**.
  - You'll need to register an app on GitHub's [developer portal](https://developer.github.com/apps/building-oauth-apps/) to obtain the **Client ID** and **Client Secret**.
  - After registering an app on GitHub's developer portal, enter your GitHub **Client ID** and **Client Secret** and then click **Save**.
  - Make sure your Firebase OAuth redirect URI (e.g. my-app-12345.firebaseapp.com/__/auth/handler) is set as your
    Authorization callback URL in your app's settings page on your [GitHub app's config](https://developer.github.com/apps/building-oauth-apps/).
- In Xcode, [add a custom URL scheme for your reversed client ID](https://developers.google.com/identity/sign-in/ios/start-integrating#add_a_url_scheme_to_your_project).
  - Note that you may have already done this in a previous step
  - You can find this in the `GoogleService-Info.plist`
- Run the app on your device or simulator.
- Choose **GitHub** under **Identity Providers** to launch the **GitHub Sign In** flow

See the [Getting Started with GitHub Sign In guide](https://firebase.google.com/docs/auth/ios/github-auth) for more details.

### Yahoo
#### Start by going to the [Firebase Console](https://console.firebase.google.com) and navigate to your project:
- Select the **Auth** panel and then click the **Sign In Method** tab.
  - Click **Yahoo** and turn on the **Enable** switch, then click **Save**.
  - You'll need to register an app on Yahoo's [developer portal](https://developer.yahoo.com/apps/) to obtain the **Client ID** and **Client Secret**.
  - After registering an app on Yahoo's developer portal, enter your Yahoo **Client ID** and **Client Secret** and then click **Save**.
  - Make sure your Firebase OAuth redirect URI (e.g. my-app-12345.firebaseapp.com/__/auth/handler) is set as your
    Authorization callback URL in your app's settings page on your [Yahoo app's config](https://developer.yahoo.com/apps/).
- In Xcode, [add a custom URL scheme for your reversed client ID](https://developers.google.com/identity/sign-in/ios/start-integrating#add_a_url_scheme_to_your_project).
  - You can find this in the `GoogleService-Info.plist`
- Run the app on your device or simulator.
- Choose **Yahoo** under **Identity Providers** to launch the **Yahoo Sign In** flow

See the [Getting Started with Yahoo Sign In guide](https://firebase.google.com/docs/auth/ios/yahoo-oauth) for more details.

### Facebook

We have already included the **`FBSDKLoginKit`** cocoapod in the `Podfile`. This cocoapod is **required** for **Sign In with Facebook**.

- Go to the [Facebook Developers Site](https://developers.facebook.com) and follow all
  instructions to set up a new iOS app. When asked for a bundle ID, use
  `com.google.firebase.quickstart.AuthenticationExample`. This is the default bundle identifier for this quickstart. If you change it, be sure that the bundle identifier entered on the Facebook developer console matches that of the bundle identifier for the quickstart.
- Follow Facebook's [iOS getting started guide](https://developers.facebook.com/docs/ios/getting-started/). You can skip steps 1 and 3 since
  we've already set up the dependencies and initialization code in this sample.
- Go to the [Firebase Console](https://console.firebase.google.com) and navigate to your project:
  - Select the **Auth** panel and then click the **Sign In Method** tab.
  - Click **Facebook** and turn on the **Enable** switch, then click **Save**.
  - Enter your Facebook **App Id** and **App Secret** and click **Save**.
- To finish configuring the Facebook Login Flow:
- Replace the value of `kFacebookAppID` at the top of AuthViewController.swift with your Facebook App Id
  - Note, you can also configure Facebook Login in the sample's `Info.plist`
  - In Xcode, [add a custom URL scheme for your Facebook App Id](https://developers.google.com/identity/sign-in/ios/start-integrating#add_a_url_scheme_to_your_project).
  - The **URL Scheme** should be in the format of `'fb' + the Facebook App Id`
    - Example: `fb1234567890`
- Run the app on your device or simulator.
- Choose **Facebook** under **Identity Providers** to launch the **Facebook Sign In** flow

### Email/Password Setup
#### Start by going to the [Firebase Console](https://console.firebase.google.com) and navigate to your project:
  - Select the **Auth** panel and then click the **Sign In Method** tab.
  - Click **Email/Password** and turn on the **Enable** switch, then click **Save**.
- Run the app on your device or simulator.
- Choose **Email & Password** to launch the **Email & Password Sign In** flow

See the [Getting Started with Password-based Sign In guide](https://firebase.google.com/docs/auth/ios/password-auth) for more details.

## Other Auth Methods

### Email Link/Passwordless

Email Link authentication, which is also referred to as Passwordless authentication, works by sending a verification email to a user requesting to sign in. This verification email contains a special **Dynamic Link** that links the user back to your app, completing authentication in the process. In order to configure this method of authentication, we will use [Firebase Dynamic Links](https://firebase.google.com/docs/dynamic-links), which we will need to set up.

#### Start by going to the [Firebase Console](https://console.firebase.google.com) and navigate to your project:
  - Select the **Auth** panel and then click the **Sign In Method** tab.
  - Click **Email/Password** and ensure it is enabled.
  - Turn on **Email link (passwordless sign-in)**, then click **Save**.

#### Configuring Dynamic Links
As we mentioned above, we will need to configure dynamic links for this auth flow.

- Go to the project's settings on the Firebase console. When enabling dynamic links, you will need to add an **App Store ID** and a **Team ID**. Feel free to make up the **App Store ID** (ex: 123456789). For the **Team ID**, enter an id affiliated with an Apple Developer account.
- Navigate to the **Dynamic Links** in the Firebase Console and click **Get Started**
- Enter a domain. Something like **authenticationexample.page.link** works. Note, this domain will likely be taken so adjust **authenticationexample** accordingly (ex: authenticationexample123). Either way, be sure to add the **.page.link** to complete the domain link!
- Now, copy the domain you created above and navigate in Xcode to the **Signing & Capabilities** tab of the app's main target. You will need to add the [Associated Domains](https://developer.apple.com/documentation/safariservices/supporting_associated_domains_in_your_app) capability. If your project has automatically manage signing checked (also on this tab), you can add the Associated Domains capability by tapping the "+" button (also on that tab). If not, you will need to add this capability on the Apple Developer console and download the resulting provisioning profile before moving to the next steps. Please refer to the Firebase docs for more info.
- Once you have the Associated Domains capability enabled and have copied the domain you created on the Firebase Console, paste `applinks:[insert the domain you copied]` into the Associated Domains section on either Xcode or Apple developer console (depending on how you set up Associated Domains in the previous step)
  - Example: `applinks: authenticationexample.page.link`
- Now let's create the dynamic link that will be used in the Passwordless login flow. Return to the Dynamic Links tab on the Firebase Console. Click **New Dynamic Link**, then:
    - Setup your short URL. Feel free to put whatever here, like "demo", "login, or "passwordless" for example. Click **Next**.
    - For the Deep Link URL, configure the URL to look like:
    >        https://[insert an authorized domain]/login?email=email
    >For the authorized domain ⬆, go to the the Authentication tab, then click the "Settings" tab, and select the "Authorized domains" section. Copy the domain that looks like `[the app's name].firebaseapp.com`. Paste this entire domain into the Deep Link we are creating above. You can also instead allowlist the dynamic links URL prefix and use that here as well.
    - On step 3, **Define link behavior for iOS**, select **Open the deep link in your iOS App** and make sure your app is selected in the drop down.
    - Configure the following steps as you please and then hit **Create**!

  - Dynamic links use your app's bundle identifier as a url scheme by default. In Xcode, [add a custom URL scheme for your **bundle identifier**](https://developers.google.com/identity/sign-in/ios/start-integrating#add_a_url_scheme_to_your_project).
  - Last todo! Navigate to `sendSignInLink()` in `PasswordlessViewController.swift. Within the method, there is a `stringURL` constant. Paste in the long deeplink you created from the steps above for the `authorizedDomain` property above the method. It should look something like:
```swift
    let stringURL = "https://\(authorizedDomain)/login"
```

- Run the app on your device or simulator.
    - Select **Email Link/Passwordless**. This will present a login screen where you can enter an email for the verification email to be sent to.
    - Enter an email and tap **Send Sign In Link**. While keeping the current view controller displayed, switch to a mail app and wait to receive the verification email.
    - Once the email has been received, open it and tap the sign in link. This will link back to the sample and finish the login flow.

See the [Getting Started with Email Link/Passwordless Sign In guide](https://firebase.google.com/docs/auth/ios/email-link-auth) for more details.

### So how does this work?

We will start by taking a look at `PasswordlessViewController.swift`. If you are currently running the app, select the "Email Link/Passwordless" authentication option.

The user is prompted for an email to be used in the verification process. When the **Send Sign In Link** button is tapped, we configure our verification link by adding the user's email to the dynamic link we created earlier. Then we send a send the link to the user's email. You can edit the format of these verification emails on the [Firebase Console](https://console.firebase.google.com/).

When the user receives the verification email, they can open the link contained in the email to be redirected back to the app (using the power of [Dynamic Links](https://firebase.google.com/docs/dynamic-links) 😎. On apps using the [`SceneDelegate`](https://developer.apple.com/documentation/uikit/uiscenedelegate) API,  opening the incoming dynamic link will be handled in `UIWindowSceneDelegate`'s  `func scene(_ scene: UIScene, continue userActivity: NSUserActivity)` method. This method can be implemented in  `SceneDelegate.swift`. Since the sample uses the `SceneDelegate` API, you can check out the implementation in SceneDelegate.swift. We basically pass the incoming link to a helper method that will do a few things:

```swift
// SceneDelegate.swift

private func handleIncomingDynamicLink(_ incomingURL: URL) {

    let link = incomingURL.absoluteString

    // Here, we check if our dynamic link is a sign-link (the one we emailed our user!)
    if Auth.auth().isSignIn(withEmailLink: link) {

        // Save the link as it will be used in the next step to complete login
        UserDefaults.standard.set(link, forKey: "Link")

        // Post a notification to the PasswordlessViewController to resume authentication
        NotificationCenter.default.post(Notification(name: Notification.Name("PasswordlessEmailNotificationSuccess")))
    }
}
```

If the incoming dynamic link is a sign-in link, then we post a notification that pretty much says: "Hey! A user just opened a verification dynamic link that we emailed them and we need to complete the authentication!"

This takes us back to our  `PasswordlessViewController.swift`, where we registered for this exact notification. When the notification is posted, we will receive it here and call the `passwordlessSignIn()` method to complete the authentication. In this method, we used Firebase Auth's `Auth.auth().signIn(withEmail: String, link: String)` which, behind the scenes, checks that this link was the link we originally sent to the associated email and if so, signs in the user! 🥳

### Phone Number

When Firebase Auth uses Phone Number authentication, Auth will attempt to send a silent Apple Push Notification (APN) to the device to confirm that the phone number being used is associated with the device. If APNs (which, like Sign In with Apple, are a [capability](https://developer.apple.com/documentation/xcode/adding_capabilities_to_your_app) you can enable in Xcode or on the Apple Developer Console) are not enabled or configured correctly, Auth will instead present a web view with a reCAPTCHA verification flow.

#### Start by going to the [Firebase Console](https://console.firebase.google.com) and navigate to your project:
  - Select the **Auth** panel and then click the **Sign In Method** tab.
  - Click **Phone** and turn on the **Enable** switch, then click **Save**.
  - Run the app on your device or simulator.
  - Choose **Phone Number**  to launch the **Phone Number Authentication** flow
  - After entering a phone number, please wait roughly 5 seconds to allow Firebase Auth to present the necessary flow.
  See the official [Firebase docs for phone authentication](https://firebase.google.com/docs/auth/ios/phone-auth) for more info!

### Anonymous Authentication
#### Start by going to the [Firebase Console](https://console.firebase.google.com) and navigate to your project:
  - Select the **Auth** panel and then click the **Sign In Method** tab.
  - Click **Anonymous** and turn on the **Enable** switch, then click **Save**.
  - Run the app on your device or simulator.
  - Choose **Anonymous Authentication**  to launch the **Anonymous Sign In** flow
  See the official [Firebase docs for anonymous authentication](https://firebase.google.com/docs/auth/ios/anonymous-auth) for more info!

### Custom Auth System

Firebase Auth can manage authentication for use cases that utilize a custom auth system. Ensure you have an authentication server capable of producing custom signed tokens. When a user signs in, make a request for a signed token from your authentication server.

After your server returns the token, pass that into  Firebase Auth's `signIn(withCustomtoken: String)` method to complete the authentication process. In the sample, you can demo signing in with tokens you generate. See `CustomAuthViewController.swift` for more info.

If you wish to setup a custom auth system. The below steps can help in its configuration.
- In the [Firebase Console](https://console.firebase.google.com/), navigate to **Project settings**:
    - Navigate to the **Service accounts** tab.
    - Locate the section **All service account**, and click on the `X service accounts` link. This will take you to the Google Cloud Console.
- In the [Google Cloud Console](https://console.cloud.google.com):
    - Make sure the right Firebase project is selected.
    - From the left "hamburger" menu navigate to the **API Manager** tab.
    - Click on the **Credentials** item in the left column.
    - Click **New credentials** and select **Service account key**. Select **New service account**,
    pick any name, and select **JSON** as the key type. Then click **Create**.
    - You should now have a new JSON file for your service account in your Downloads directory.
- Open the file `web/auth.html` in your computer's web browser. The `auth.html` file can now be found in the current directory's `LegacyAuthQuickstart` subdirectory.
    - Click **Choose File** and upload the JSON file you just downloaded.
    - Enter any User ID and click **Generate**.
    - Copy the token link displayed.
- Run the app on your device or simulator.
    - Select **Custom Auth system**
    - Paste in the token you generated earlier.
    - Pressing **Login** should then login the token's affiliated user.


# Support

-  [Firebase Support](https://firebase.google.com/support/)
