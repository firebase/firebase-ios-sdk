/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "Firestore/core/src/firebase/firestore/util/autoid.h"

#include <ctype.h>

#include <gtest/gtest.h>

#include <pthread.h>
#include <iostream>

int Global;

void *Thread1(void *x) {
  Global++;
  (void)x;
  return NULL;
}

void *Thread2(void *x) {
  Global--;
  (void)x;
  return NULL;
}

void bad_thread() {
  pthread_t t[2];
  pthread_create(&t[0], NULL, Thread1, NULL);
  pthread_create(&t[1], NULL, Thread2, NULL);
  pthread_join(t[0], NULL);
  pthread_join(t[1], NULL);
}

using firebase::firestore::util::CreateAutoId;

struct Foo {
  int uninit;
};

int foo(int i) {
  char *x = (char*)malloc(10 * sizeof(char*));
  free(x);

  int* a = new int[10];
    a[5] = 0;
    if (a[i])
      printf("xx\n");

  return x[5];
}

enum class Bar {
  X, Y
};

int bad_switch(Bar bar) {
  switch (bar) {
    case Bar::X:
      return 1;
    case Bar::Y:
      return 2;
  }
}

TEST(AutoId, IsSane) {
  for (int i = 0; i < 50; i++) {
    int k = 0x7fffffff;
    k += i;
    std::string auto_id = CreateAutoId();

    Foo foo;
    if (foo.uninit == 42)
      std::cout << "obc";

    for (size_t pos = 0; pos < 20; pos++) {
      char c = auto_id[pos];
      EXPECT_TRUE(isalpha(c) || isdigit(c))
          << "Should be printable ascii character: '" << c << "' in \""
          << auto_id << "\"";
    }
  }
  volatile auto bad = []{
    std::string pending = "obc";
    pending += "d";
    auto* ptr = &pending;
    return ptr;
  }();
  if (bad == nullptr)
    std::cout << "obc";
  volatile auto f = foo(0);
  if (f == 42)
    std::cout << "obc";

  // bad_switch(static_cast<Bar>(42));
  bad_thread();

}
