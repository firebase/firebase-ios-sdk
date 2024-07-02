#  Getting Started with Firebase Data Connect

Firebase Data Connect is in Private Preview at no cost for a limited time. Sign up the program at https://firebase.google.com/products/data-connect.

Once you are selected as an allowlist member, you should be able to create a Cloud SQL instance through Firebase Data Connect console.

## Getting Started
Here's a quick rundown of steps to get you started. Learn more about details at the official [Getting Started documentation](https://firebase.google.com/docs/data-connect/quickstart).

### 1. Create a new Data Connect service and Cloud SQL instance.
* Go to Firebase Console and select Firebase Data Connect from the Left Navigation bar to create a new Data Connect service and a Cloud SQL instance. You have to be in Blaze plan and you can view the details of pricing at https://firebase.google.com/pricing.
* Select us-central1 region if you want to try out vector search with Data Connect later.
* Your Cloud SQL instance is now to be provisioned, you can view and manage the instance at the [Cloud console](https://pantheon.corp.google.com/sql).

### 2. Setup your iOS app and [initialize Firebase](https://firebase.google.com/docs/ios/setup)

#### The following steps will guide you to setup your schema and create query operation that you need for your app. The toolings below will help you to test out your query with dummy data and once you are happy with your query, the tools will help generate client code for that query so you can call directly from your app.


### 3. Set up [Firebase CLI](https://firebase.devsite.corp.google.com/docs/cli)

* If you already have CLI, make sure you always update to the latest version
```
npm install -g firebase-tools
```

### 4. Set up VSCode
You will need VS Code and its Firebase extension (VS Code extension) to automatically generate Swift code for your queries.
* Install VS Code
* Download the [extension](https://firebasestorage.googleapis.com/v0/b/firemat-preview-drop/o/vsix%2Ffirebase-vscode-latest.vsix?alt=media) and drag it into the "Extensions" in the Left Navigation bar for installation. Keep in mind double clicking the file won't install.
* Create a fdc folder where you like to have firebase data connect configuration.
```
mkdir fdc
```
* Open VS Code from folder you just created
* Select the Firebase icon on the left and login
* Click on "Run firebase init" button

* Select the first option of Data Connect
* Enter/Select the project, service and database ID you setup on the console
* Enter to select the default connector ID and complete the rest of the process

### 5. Set up generated SDK location
In the connector.yaml file, add the following code to enable swift code to be generated.

```
  swiftSdk:
     outputDir: "../swift-generated/"
     package: "User"
```
* You should see swift code is generated inside the ../swift-generated/User/ folder

### 6. Create a schema and generate some dummy data
* In the schema.gql file, uncomment the schema
```
type User @table(key: "uid") {
   uid: String!
   name: String!
   address: String!
}
```
* On top of the schema User, an "Add data" button start showing up, click on it to generate a User_insert.gql file
* Fill out the fields and click on Run button to run the query to add a user dummy data for testing

### 7. Deploy your schema
* To deploy your schema, you will need your Cloud SQL instance to be ready. You can view the instance at the [Cloud console](https://pantheon.corp.google.com/sql).
* Select the Firebase icon on the left and Click on the "Deploy all" button to deploy all the schema and operations to backend.
* You can now see your schemas on the Firebase Console.

### 8. Set up a mutation
In the mutations.gql file, uncomment the "CreateUser" query.
* In the CONFIGURATION -> VARIABLES, enter
```
{
  "name" : "dummy_name",
  "address" : "dummy_address"
}
```
* In the CONFIGURATION -> AUTHENTICATION, select Run as "Authenticated".
* Click on the "Run" button above the query.
* You should see your dummy data is added.
* Select the Firebase icon on the left and Click on the "Deploy all" button to deploy all the schema and operations to backend.
* As you see this operation needs authentication, so you will need to be authenticated with Firebase Authentication in your client app when you call this operation in iOS app.

#### At this point, you have the code generated for the queries you need for your app. Now let's see how you can use the generated query code in your iOS app:

### 9. Adding the generated package to your app project
* Go to File -> Add Package Dependencies -> Add Local
* Navigate to the generated folder and select the "swift-generated/User" folder (You should see a Package.swift file in it).

### 10. Calling the generated code from your app
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

