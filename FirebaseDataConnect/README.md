#  Getting Started with Firebase Data Connect

Firebase Data Connect is in Private Preview at no cost. Sign up the program at https://firebase.google.com/products/data-connect.

Once you are selected as an allowlist member, you should be able to create a Cloud SQL instance through Firebase Data Connect console at no cost.

Here's a quick rundown of steps to get you started. If you want to learn more about details, you can check out the [Getting Started documentation](https://firebase.google.com/docs/data-connect/quickstart).

1. Go to Firebase Console and Firebase Data Connect Navbar to create a new Data Connect service and a Cloud SQL instance. You will have to be in Blaze plan and you can view the details of pricing at https://firebase.google.com/pricing.
-- Select us-central1 region if you want to try out vector search with Data Connect later.
-- Wait for the Cloud SQL instance to be provisioned, you can view and manage the instance at the [Cloud console](https://pantheon.corp.google.com/sql).

2. Enable Firebase Data Connect experiment
```firebase experiements:enable dataconnect
```

3. Set up [Firebase CLI](https://firebase.devsite.corp.google.com/docs/cli)
-- If you already have CLI, make sure you always update to the latest version
```
npm install -g firebase-tools
```

4. You will need VS Code and its Firebase extension (VS Code extension) to automatically generate Swift code for your queries.
-- Install VS Code
-- Download the [extension](https://firebasestorage.googleapis.com/v0/b/firemat-preview-drop/o/vsix%2Ffirebase-vscode-latest.vsix?alt=media) and install in VS Code
-- Create a fdc folder
```mkdir fdc
```
-- Open VS Code form FDC folder
-- Select the Firebase icon on the left and login
-- Click on "Run firebase init" button

---Select Data Connect
---Select the project, service and database ID you setup on the console
---Enter to select the default connector ID and complete the rest of the process

5. In the schema.gql file, uncomment the schema
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

7. In the queries.gql file, uncomment the "ListUsers" query and execute the query as well. You should see your dummy data is listed.

8. Select the Firebase icon on the left and Click on the "Deploy all" button to deplouy all the schema and operations to backend.

-----------------------------------At this point, you have the code generated for the queries you need for your app--------------

Now let's see how you can use the generated query code in your iOS app:

9. In the connector.yaml file, add the following code to enable swift code to be generated

```
  swiftSdk:
     outputDir: "../iosgen/"
     package: "User"
     coreSdkPackageLocation: "file:///Users/[YOURUSERID]/github/firebase-ios-sdk"
```
-- You should see swift code is generated inside the iosgen folder

10. Setup your iOS app and [initialize Firebase](https://firebase.google.com/docs/ios/setup)
-- Add generated code from iosgen to your Xcode

11. Download Firebase Data Connect SDK by modifying SPM file. It's still in private preview so it's under the "dataconnect' branch



12. In your app, start using the generated code
```
import FirebaseDataConnect
import Users //change this to the name of your generated package

struct MovieListView: View {

  //if talking to emulator
  @StateObject var UsersListRef = DataConnect.emulatedUsersClient.listUsersQueryRef()

  //if talking to prod service
  // @StateObject var userListRef = DataConnect.usersClient.listUsersQueryRef()

  var body: some View {
    NavigationStack {
      VStack {
        if let data = userListRef.data {
          List {
            ForEach(data.users) { user in
              VStack {
   		// Note: this is a dummy example to show how to run query on client apps
  		// It's not best practice to display users info in production
		Text(user.name)
	      }
            }
          }
        }
	}
    }
  }

}

```





















