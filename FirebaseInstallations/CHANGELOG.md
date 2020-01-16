# v1.0.1 -- M62

- [changed] Throw an exception when there are missing required `FIROptions` parameters. (#4683)

# v1.0.0 -- M62

- [added] The Firebase Installations Service is an infrastructure service for Firebase services that creates unique identifiers and authentication tokens for Firebase clients (called "Firebase Installations") enabling Firebase Targeting, i.e. interoperation between Firebase services.
- [added] The Firebase Installations SDK introduces the Firebase Installations API. Developers that use API-restrictions for their API-Key may experience blocked requests (https://stackoverflow.com/questions/58495985/). This problem can be mitigated by following the instructions found [here](API_KEY_RESTRICTIONS.md).