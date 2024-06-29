#  Getting Started with Firebase Data Connect

Firebase Data Connect is in Private Preview at no cost. Sign up the program at https://firebase.google.com/products/data-connect.

Once you are selected as an allowlist member, you should be able to create a Cloud SQL instance through Firebase Data Connect console at no cost.

Here's a quick rundown of steps to get you started. If you want to learn more about details, you can check out the [Getting Started documentation](https://firebase.google.com/docs/data-connect/quickstart).

1. Go to Firebase Console and Firebase Data Connect Navbar to create a new Data Connect service and a Cloud SQL instance. You will have to be in Blaze plan and you can view the details of pricing at https://firebase.google.com/pricing.
-- Select us-central1 region if you want to try out vector search with Data Connect later.
-- Wait for the Cloud SQL instance to be provisioned, you can view and manage the instance at the [Cloud console](https://pantheon.corp.google.com/sql).


2. Set up [Firebase CLI](https://firebase.devsite.corp.google.com/docs/cli)
-- If you already have CLI, make sure you always update to the latest version
```
npm install -g firebase-tools
```

3. You will need VS Code and its Firebase extension (VS Code extension) to automatically generate Swift code for your queries.
-- Install VS Code
-- Download the [extension](https://firebasestorage.googleapis.com/v0/b/firemat-preview-drop/o/vsix%2Ffirebase-vscode-latest.vsix?alt=media) and drag it into the "Extensions" Left Nav bar for installation.
-- Create a fdc folder
```mkdir fdc
```
-- Open VS Code form FDC folder
-- Select the Firebase icon on the left and login
-- Click on "Run firebase init" button

---Select Data Connect
---Select the project, service and database ID you setup on the console
---Enter to select the default connector ID and complete the rest of the process

4. In the schema.gql file, uncomment the schema
```
type User @table(key: "uid") {
   uid: String!
   name: String!
   address: String!
}
```
-- On top of the schema User, an "Add data" button start showing up, click on it to generate a User_insert.gql file
--- Fill out the fields and click on Run button to run the query to add a user dummy data for testing

6. Select the Firebase icon on the left and Click on the "Deploy all" button to deplouy all the schema and operations to backend.
-- You can now see your schemas on the Firebase Console.

7. In the mutations.gql file, uncomment the "CreateUser" query.
-- In the CONFIGURATION -> VARIABLES, enter
```
{
  "name" : "dummy_name",
  "address" : "dummy_address"
}
```
-- In the CONFIGURATION -> AUTHENTICATION, select Run as "Authenticated".
-- Click on the "Run" button above the query.
-- You should see your dummy data is added.

8. Select the Firebase icon on the left and Click on the "Deploy all" button to deplouy all the schema and operations to backend.

9. In the connector.yaml file, add the following code to enable swift code to be generated.

```
  swiftSdk:
     outputDir: "../swift-generated/"
     package: "User"
     coreSdkPackageLocation: "file:///Users/[YOURUSERID]/github/firebase-ios-sdk"
```
-- You should see swift code is generated inside the ../swift-generated/User/ folder
-- The coreSdkPackageLocation should be where you check out the firebase-ios-sdk repo and make sure you check out the "dataconnect" branch because Firebase Data Connect is currently under "dataconnect" branch during Private Preview.

---------*At this point, you have the code generated for the queries you need for your app*----------

Now let's see how you can use the generated query code in your iOS app:


10. Setup your iOS app and [initialize Firebase](https://firebase.google.com/docs/ios/setup)
-- Go to File -> Add Package Dependencies -> Add Local
-- Navigate to the generated folder and select it


11. In your app, start using the generated code
```
import FirebaseDataConnect
import Users //change this to the name of your generated package

func executeFDCCreateUserQuery() {
    Task {
      do {
        let result = try await DataConnect.defaultConnectorClient.createUserMutationRef(name: "dummyUserName", address: "dummyUserAddress").execute()
      } catch {
      }
    }
  }

```





















