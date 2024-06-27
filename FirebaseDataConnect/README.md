#  Getting Started with Firebase Data Connect

Firebase Data Connect is in Private Preview with no cost. Sign up the program at https://firebase.google.com/products/data-connect.

Once you are selected as an allowlist member, you should be able to create a Cloud SQL instance through Firebase Data Connect console at no cost. Follow the Getting started guide https://firebase.google.com/docs/data-connect/quickstart

Here's a quick rundown of steps to get you started:

1. Go to Firebase Console and Firebase Data Connect bar to create a new Data Connect service and a Cloud SQL instance. You will have to be in Blaze plan and you can view the details of pricing at https://firebase.google.com/pricing.
-- Select us-central1 region if you want to try out vector search with Data Connect later.
-- Wait for the Cloud SQL instance to be provisioned, you can view and manage the instance at https://pantheon.corp.google.com/sql.

2. Enable Firebase Data Connect experiment
```firebase experiements:enable dataconnect
```

3. Set up Firebase CLI at https://firebase.devsite.corp.google.com/docs/cli
-- If you already have CLI, make sure you always update to the latest version
```
npm install -g firebase-tools
```

4. You will need VS Code and its Firebase extension (VS Code extension) to automatically generate Swift code for your queries.
-- Install VS Code
-- Download the extension from https://firebasestorage.googleapis.com/v0/b/firemat-preview-drop/o/vsix%2Ffirebase-vscode-latest.vsix?alt=media and install in VS Code
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
6. On top of the schema User, an "Add data" button start showing up, click on it to generate a User_insert.gql file
--- Fill out the fields and click on Run button to run the query to add a user dummy data for testing

7. Select the Firebase icon on the left and Click on the "Deploy all" button to deplouy all the schema and operations to backend.
-- You can now see your schemas on the Firebase Console.

8. Do the same opeartions for email schema
```
type Email @table {
   subject: String!
   sent: Date!
   text: String!
   from: User!
}
```

9. In the queries.gql file, uncomment the ListEmails query and execute the query as well. You should see your dummy data is listed.
10. Select the Firebase icon on the left and Click on the "Deploy all" button to deplouy all the schema and operations to backend.






















