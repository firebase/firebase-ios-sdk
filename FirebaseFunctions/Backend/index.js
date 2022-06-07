// Copyright 2018 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

const assert = require('assert');
const functions = require('firebase-functions');

exports.dataTest = functions.https.onRequest((request, response) => {
  assert.deepEqual(request.body, {
    data: {
      bool: true,
      int: 2,
      long: {
        value: '9876543210',
        '@type': 'type.googleapis.com/google.protobuf.Int64Value',
      },
      string: 'four',
      array: [5, 6],
      'null': null,
    }
  });
  response.send({
    data: {
      message: 'stub response',
      code: 42,
      long: {
        value: '420',
        '@type': 'type.googleapis.com/google.protobuf.Int64Value',
      },
    }
  });
});

exports.scalarTest = functions.https.onRequest((request, response) => {
  assert.deepEqual(request.body, { data: 17 });
  response.send({ data: 76 });
});

exports.tokenTest = functions.https.onRequest((request, response) => {
  assert.equal('Bearer token', request.get('Authorization'));
  assert.deepEqual(request.body, { data: {} });
  response.send({ data: {} });
});

exports.FCMTokenTest = functions.https.onRequest((request, response) => {
  assert.equal(request.get('Firebase-Instance-ID-Token'), 'fakeFCMToken');
  assert.deepEqual(request.body, { data: {} });
  response.send({ data: {} });
});

exports.nullTest = functions.https.onRequest((request, response) => {
  assert.deepEqual(request.body, { data: null });
  response.send({ data: null });
});

exports.missingResultTest = functions.https.onRequest((request, response) => {
  assert.deepEqual(request.body, { data: null });
  response.send({});
});

exports.unhandledErrorTest = functions.https.onRequest((request, response) => {
  // Fail in a way that the client shouldn't see.
  throw 'nope';
});

exports.unknownErrorTest = functions.https.onRequest((request, response) => {
  // Send an http error with a body with an explicit code.
  response.status(400).send({
    error: {
      status: 'THIS_IS_NOT_VALID',
      message: 'this should be ignored',
    },
  });
});

exports.explicitErrorTest = functions.https.onRequest((request, response) => {
  // Send an http error with a body with an explicit code.
  // Note that eventually the SDK will have a helper to automatically return
  // the appropriate http status code for an error.
  response.status(400).send({
    error: {
      status: 'OUT_OF_RANGE',
      message: 'explicit nope',
      details: {
        start: 10,
        end: 20,
        long: {
          value: '30',
          '@type': 'type.googleapis.com/google.protobuf.Int64Value',
        },
      },
    },
  });
});

exports.httpErrorTest = functions.https.onRequest((request, response) => {
  // Send an http error with no body.
  response.status(400).send();
});

// Regression test for https://github.com/firebase/firebase-ios-sdk/issues/9855
exports.throwTest = functions.https.onCall((data) => {
  throw new functions.https.HttpsError('invalid-argument', 'Invalid test requested.');
});

exports.timeoutTest = functions.https.onRequest((request, response) => {
  // Wait for longer than 500ms.
  setTimeout(() => response.send({data: true}), 500);
});

