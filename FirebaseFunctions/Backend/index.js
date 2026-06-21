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
const functionsV1 = require('firebase-functions/v1');
const functionsV2 = require('firebase-functions/v2');

// MARK: - Utilities

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
};

// MARK: - Callable Functions

exports.dataTest = functionsV1.https.onRequest((request, response) => {
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

exports.scalarTest = functionsV1.https.onRequest((request, response) => {
  assert.deepEqual(request.body, { data: 17 });
  response.send({ data: 76 });
});

exports.tokenTest = functionsV1.https.onRequest((request, response) => {
  assert.equal('Bearer token', request.get('Authorization'));
  assert.deepEqual(request.body, { data: {} });
  response.send({ data: {} });
});

exports.FCMTokenTest = functionsV1.https.onRequest((request, response) => {
  assert.equal(request.get('Firebase-Instance-ID-Token'), 'fakeFCMToken');
  assert.deepEqual(request.body, { data: {} });
  response.send({ data: {} });
});

exports.nullTest = functionsV1.https.onRequest((request, response) => {
  assert.deepEqual(request.body, { data: null });
  response.send({ data: null });
});

exports.missingResultTest = functionsV1.https.onRequest((request, response) => {
  assert.deepEqual(request.body, { data: null });
  response.send({});
});

exports.unhandledErrorTest = functionsV1.https.onRequest((request, response) => {
  // Fail in a way that the client shouldn't see.
  throw 'nope';
});

exports.unknownErrorTest = functionsV1.https.onRequest((request, response) => {
  // Send an http error with a body with an explicit code.
  response.status(400).send({
    error: {
      status: 'THIS_IS_NOT_VALID',
      message: 'this should be ignored',
    },
  });
});

exports.explicitErrorTest = functionsV1.https.onRequest((request, response) => {
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

exports.httpErrorTest = functionsV1.https.onRequest((request, response) => {
  // Send an http error with no body.
  response.status(400).send();
});

// Regression test for https://github.com/firebase/firebase-ios-sdk/issues/9855
exports.throwTest = functionsV1.https.onCall((data) => {
  throw new functionsV1.https.HttpsError('invalid-argument', 'Invalid test requested.');
});

exports.timeoutTest = functionsV1.https.onRequest((request, response) => {
  // Wait for longer than 500ms.
  setTimeout(() => response.send({ data: true }), 500);
});

const streamData = ["hello", "world", "this", "is", "cool"]

async function* generateText() {
  for (const chunk of streamData) {
    yield chunk;
    await sleep(100);
  }
};

exports.genStream = functionsV2.https.onCall(
  async (request, response) => {
    if (request.acceptsStreaming) {
      for await (const chunk of generateText()) {
        response.sendChunk(chunk);
      }
    }
    return streamData.join(" ");
  }
);

exports.genStreamError = functionsV2.https.onCall(
  async (request, response) => {
    // Note: The functions backend does not pass the error message to the
    // client at this time.
    throw Error("BOOM")
  }
);

const weatherForecasts = {
  Toronto: { conditions: 'snowy', temperature: 25 },
  London: { conditions: 'rainy', temperature: 50 },
  Dubai: { conditions: 'sunny', temperature: 75 }
};

async function* generateForecast(locations) {
  for (const location of locations) {
    yield { 'location': location,  ...weatherForecasts[location.name] };
    await sleep(100);
  }
};

exports.genStreamWeather = functionsV2.https.onCall(
  async (request, response) => {
    const forecasts = [];
    if (request.acceptsStreaming) {
      for await (const chunk of generateForecast(request.data)) {
        forecasts.push(chunk)
        response.sendChunk(chunk);
      }
    }
    return { forecasts };
  }
);

exports.genStreamWeatherError = functionsV2.https.onCall(
  async (request, response) => {
    if (request.acceptsStreaming) {
      for await (const chunk of generateForecast(request.data)) {
        // Remove the location field, since the SDK cannot decode the message
        // if it's there.
        delete chunk.location;
        response.sendChunk(chunk);
      }
    }
    return "Number of forecasts generated: " + request.data.length;
  }
);

exports.genStreamEmpty = functionsV2.https.onCall(
  async (request, response) => {
    if (request.acceptsStreaming) {
      // Send no chunks
    }
    // Implicitly return null.
  }
);

exports.genStreamResultOnly = functionsV2.https.onCall(
  async (request, response) => {
    if (request.acceptsStreaming) {
      // Do not send any chunks.
    }
    return "Only a result";
  }
);

exports.genStreamLargeData = functionsV2.https.onCall(
  async (request, response) => {
    if (request.acceptsStreaming) {
      const largeString = 'A'.repeat(10000);
      const chunkSize = 1024;
      for (let i = 0; i < largeString.length; i += chunkSize) {
        const chunk = largeString.substring(i, i + chunkSize);
        response.sendChunk(chunk);
        await sleep(100);
      }
    }
    return "Stream Completed";
  }
);
