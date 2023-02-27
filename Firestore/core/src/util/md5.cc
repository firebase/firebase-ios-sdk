/*
 * Copyright 2023 Google LLC
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

#include "Firestore/core/src/util/md5.h"

#include <cstdlib>
#include <cstring>

namespace firebase {
namespace firestore {
namespace util {

// This anonymous namespace contains the md5 implementation copied from
// BoringSSL.
namespace {

// MD5_CBLOCK is the block size of MD5.
#define MD5_CBLOCK 64

// MD5_DIGEST_LENGTH is the length of an MD5 digest.
#define MD5_DIGEST_LENGTH 16

struct md5_state_st {
  uint32_t h[4];
  uint32_t Nl, Nh;
  uint8_t data[MD5_CBLOCK];
  unsigned num;
};
typedef struct md5_state_st MD5_CTX;

inline void OPENSSL_memset(void* dst, int c, size_t n) {
  if (n != 0) {
    std::memset(dst, c, n);
  }
}

inline void OPENSSL_memcpy(void* dst, const void* src, size_t n) {
  if (n != 0) {
    std::memcpy(dst, src, n);
  }
}

inline uint32_t CRYPTO_rotl_u32(uint32_t value, int shift) {
#if defined(_MSC_VER)
  return _rotl(value, shift);
#else
  return (value << shift) | (value >> ((-shift) & 31));
#endif
}

inline uint32_t CRYPTO_bswap4(uint32_t x) {
  x = (x >> 16) | (x << 16);
  x = ((x & 0xff00ff00) >> 8) | ((x & 0x00ff00ff) << 8);
  return x;
}

inline uint32_t CRYPTO_load_u32_le(const void* in) {
  uint32_t v;
  OPENSSL_memcpy(&v, in, sizeof(v));
  return v;
}

inline void CRYPTO_store_u32_le(void* out, uint32_t v) {
  OPENSSL_memcpy(out, &v, sizeof(v));
}

inline void CRYPTO_store_u32_be(void* out, uint32_t v) {
  v = CRYPTO_bswap4(v);
  OPENSSL_memcpy(out, &v, sizeof(v));
}

#define F(b, c, d) ((((c) ^ (d)) & (b)) ^ (d))
#define G(b, c, d) ((((b) ^ (c)) & (d)) ^ (c))
#define H(b, c, d) ((b) ^ (c) ^ (d))
#define I(b, c, d) (((~(d)) | (b)) ^ (c))

#define R0(a, b, c, d, k, s, t)            \
  do {                                     \
    (a) += ((k) + (t) + F((b), (c), (d))); \
    (a) = CRYPTO_rotl_u32(a, s);           \
    (a) += (b);                            \
  } while (0)

#define R1(a, b, c, d, k, s, t)            \
  do {                                     \
    (a) += ((k) + (t) + G((b), (c), (d))); \
    (a) = CRYPTO_rotl_u32(a, s);           \
    (a) += (b);                            \
  } while (0)

#define R2(a, b, c, d, k, s, t)            \
  do {                                     \
    (a) += ((k) + (t) + H((b), (c), (d))); \
    (a) = CRYPTO_rotl_u32(a, s);           \
    (a) += (b);                            \
  } while (0)

#define R3(a, b, c, d, k, s, t)            \
  do {                                     \
    (a) += ((k) + (t) + I((b), (c), (d))); \
    (a) = CRYPTO_rotl_u32(a, s);           \
    (a) += (b);                            \
  } while (0)

#ifdef X
#undef X
#endif
static void md5_block_data_order(uint32_t* state,
                                 const uint8_t* data,
                                 size_t num) {
  uint32_t A, B, C, D;
  uint32_t XX0, XX1, XX2, XX3, XX4, XX5, XX6, XX7, XX8, XX9, XX10, XX11, XX12,
      XX13, XX14, XX15;
#define X(i) XX##i

  A = state[0];
  B = state[1];
  C = state[2];
  D = state[3];

  for (; num--;) {
    X(0) = CRYPTO_load_u32_le(data);
    data += 4;
    X(1) = CRYPTO_load_u32_le(data);
    data += 4;
    // Round 0
    R0(A, B, C, D, X(0), 7, 0xd76aa478L);
    X(2) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(D, A, B, C, X(1), 12, 0xe8c7b756L);
    X(3) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(C, D, A, B, X(2), 17, 0x242070dbL);
    X(4) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(B, C, D, A, X(3), 22, 0xc1bdceeeL);
    X(5) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(A, B, C, D, X(4), 7, 0xf57c0fafL);
    X(6) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(D, A, B, C, X(5), 12, 0x4787c62aL);
    X(7) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(C, D, A, B, X(6), 17, 0xa8304613L);
    X(8) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(B, C, D, A, X(7), 22, 0xfd469501L);
    X(9) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(A, B, C, D, X(8), 7, 0x698098d8L);
    X(10) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(D, A, B, C, X(9), 12, 0x8b44f7afL);
    X(11) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(C, D, A, B, X(10), 17, 0xffff5bb1L);
    X(12) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(B, C, D, A, X(11), 22, 0x895cd7beL);
    X(13) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(A, B, C, D, X(12), 7, 0x6b901122L);
    X(14) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(D, A, B, C, X(13), 12, 0xfd987193L);
    X(15) = CRYPTO_load_u32_le(data);
    data += 4;
    R0(C, D, A, B, X(14), 17, 0xa679438eL);
    R0(B, C, D, A, X(15), 22, 0x49b40821L);
    // Round 1
    R1(A, B, C, D, X(1), 5, 0xf61e2562L);
    R1(D, A, B, C, X(6), 9, 0xc040b340L);
    R1(C, D, A, B, X(11), 14, 0x265e5a51L);
    R1(B, C, D, A, X(0), 20, 0xe9b6c7aaL);
    R1(A, B, C, D, X(5), 5, 0xd62f105dL);
    R1(D, A, B, C, X(10), 9, 0x02441453L);
    R1(C, D, A, B, X(15), 14, 0xd8a1e681L);
    R1(B, C, D, A, X(4), 20, 0xe7d3fbc8L);
    R1(A, B, C, D, X(9), 5, 0x21e1cde6L);
    R1(D, A, B, C, X(14), 9, 0xc33707d6L);
    R1(C, D, A, B, X(3), 14, 0xf4d50d87L);
    R1(B, C, D, A, X(8), 20, 0x455a14edL);
    R1(A, B, C, D, X(13), 5, 0xa9e3e905L);
    R1(D, A, B, C, X(2), 9, 0xfcefa3f8L);
    R1(C, D, A, B, X(7), 14, 0x676f02d9L);
    R1(B, C, D, A, X(12), 20, 0x8d2a4c8aL);
    // Round 2
    R2(A, B, C, D, X(5), 4, 0xfffa3942L);
    R2(D, A, B, C, X(8), 11, 0x8771f681L);
    R2(C, D, A, B, X(11), 16, 0x6d9d6122L);
    R2(B, C, D, A, X(14), 23, 0xfde5380cL);
    R2(A, B, C, D, X(1), 4, 0xa4beea44L);
    R2(D, A, B, C, X(4), 11, 0x4bdecfa9L);
    R2(C, D, A, B, X(7), 16, 0xf6bb4b60L);
    R2(B, C, D, A, X(10), 23, 0xbebfbc70L);
    R2(A, B, C, D, X(13), 4, 0x289b7ec6L);
    R2(D, A, B, C, X(0), 11, 0xeaa127faL);
    R2(C, D, A, B, X(3), 16, 0xd4ef3085L);
    R2(B, C, D, A, X(6), 23, 0x04881d05L);
    R2(A, B, C, D, X(9), 4, 0xd9d4d039L);
    R2(D, A, B, C, X(12), 11, 0xe6db99e5L);
    R2(C, D, A, B, X(15), 16, 0x1fa27cf8L);
    R2(B, C, D, A, X(2), 23, 0xc4ac5665L);
    // Round 3
    R3(A, B, C, D, X(0), 6, 0xf4292244L);
    R3(D, A, B, C, X(7), 10, 0x432aff97L);
    R3(C, D, A, B, X(14), 15, 0xab9423a7L);
    R3(B, C, D, A, X(5), 21, 0xfc93a039L);
    R3(A, B, C, D, X(12), 6, 0x655b59c3L);
    R3(D, A, B, C, X(3), 10, 0x8f0ccc92L);
    R3(C, D, A, B, X(10), 15, 0xffeff47dL);
    R3(B, C, D, A, X(1), 21, 0x85845dd1L);
    R3(A, B, C, D, X(8), 6, 0x6fa87e4fL);
    R3(D, A, B, C, X(15), 10, 0xfe2ce6e0L);
    R3(C, D, A, B, X(6), 15, 0xa3014314L);
    R3(B, C, D, A, X(13), 21, 0x4e0811a1L);
    R3(A, B, C, D, X(4), 6, 0xf7537e82L);
    R3(D, A, B, C, X(11), 10, 0xbd3af235L);
    R3(C, D, A, B, X(2), 15, 0x2ad7d2bbL);
    R3(B, C, D, A, X(9), 21, 0xeb86d391L);

    A = state[0] += A;
    B = state[1] += B;
    C = state[2] += C;
    D = state[3] += D;
  }
}

#undef X

#undef F
#undef G
#undef H
#undef I
#undef R0
#undef R1
#undef R2
#undef R3

typedef void (*crypto_md32_block_func)(uint32_t* state,
                                       const uint8_t* data,
                                       size_t num_blocks);

// crypto_md32_update adds |len| bytes from |in| to the digest. |data| must be a
// buffer of length |block_size| with the first |*num| bytes containing a
// partial block. This function combines the partial block with |in| and
// incorporates any complete blocks into the digest state |h|. It then updates
// |data| and |*num| with the new partial block and updates |*Nh| and |*Nl| with
// the data consumed.
inline void crypto_md32_update(crypto_md32_block_func block_func,
                               uint32_t* h,
                               uint8_t* data,
                               size_t block_size,
                               unsigned* num,
                               uint32_t* Nh,
                               uint32_t* Nl,
                               const uint8_t* in,
                               size_t len) {
  if (len == 0) {
    return;
  }

  uint32_t l = *Nl + (((uint32_t)len) << 3);
  if (l < *Nl) {
    // Handle carries.
    (*Nh)++;
  }
  *Nh += (uint32_t)(len >> 29);
  *Nl = l;

  size_t n = *num;
  if (n != 0) {
    if (len >= block_size || len + n >= block_size) {
      OPENSSL_memcpy(data + n, in, block_size - n);
      block_func(h, data, 1);
      n = block_size - n;
      in += n;
      len -= n;
      *num = 0;
      // Keep |data| zeroed when unused.
      OPENSSL_memset(data, 0, block_size);
    } else {
      OPENSSL_memcpy(data + n, in, len);
      *num += (unsigned)len;
      return;
    }
  }

  n = len / block_size;
  if (n > 0) {
    block_func(h, in, n);
    n *= block_size;
    in += n;
    len -= n;
  }

  if (len != 0) {
    *num = (unsigned)len;
    OPENSSL_memcpy(data, in, len);
  }
}

// crypto_md32_final incorporates the partial block and trailing length into the
// digest state |h|. The trailing length is encoded in little-endian if
// |is_big_endian| is zero and big-endian otherwise. |data| must be a buffer of
// length |block_size| with the first |*num| bytes containing a partial block.
// |Nh| and |Nl| contain the total number of bits processed. On return, this
// function clears the partial block in |data| and
// |*num|.
//
// This function does not serialize |h| into a final digest. This is the
// responsibility of the caller.
inline void crypto_md32_final(crypto_md32_block_func block_func,
                              uint32_t* h,
                              uint8_t* data,
                              size_t block_size,
                              unsigned* num,
                              uint32_t Nh,
                              uint32_t Nl,
                              int is_big_endian) {
  // |data| always has room for at least one byte. A full block would have
  // been consumed.
  size_t n = *num;
  assert(n < block_size);
  data[n] = 0x80;
  n++;

  // Fill the block with zeros if there isn't room for a 64-bit length.
  if (n > block_size - 8) {
    OPENSSL_memset(data + n, 0, block_size - n);
    n = 0;
    block_func(h, data, 1);
  }
  OPENSSL_memset(data + n, 0, block_size - 8 - n);

  // Append a 64-bit length to the block and process it.
  if (is_big_endian) {
    CRYPTO_store_u32_be(data + block_size - 8, Nh);
    CRYPTO_store_u32_be(data + block_size - 4, Nl);
  } else {
    CRYPTO_store_u32_le(data + block_size - 8, Nl);
    CRYPTO_store_u32_le(data + block_size - 4, Nh);
  }
  block_func(h, data, 1);
  *num = 0;
  OPENSSL_memset(data, 0, block_size);
}

void MD5_Init(MD5_CTX* md5) {
  OPENSSL_memset(md5, 0, sizeof(MD5_CTX));
  md5->h[0] = 0x67452301UL;
  md5->h[1] = 0xefcdab89UL;
  md5->h[2] = 0x98badcfeUL;
  md5->h[3] = 0x10325476UL;
}

void MD5_Update(MD5_CTX* c, const void* data, size_t len) {
  crypto_md32_update(&md5_block_data_order, c->h, c->data, MD5_CBLOCK, &c->num,
                     &c->Nh, &c->Nl, static_cast<const uint8_t*>(data), len);
}

void MD5_Final(uint8_t out[MD5_DIGEST_LENGTH], MD5_CTX* c) {
  crypto_md32_final(&md5_block_data_order, c->h, c->data, MD5_CBLOCK, &c->num,
                    c->Nh, c->Nl, /*is_big_endian=*/0);

  CRYPTO_store_u32_le(out, c->h[0]);
  CRYPTO_store_u32_le(out + 4, c->h[1]);
  CRYPTO_store_u32_le(out + 8, c->h[2]);
  CRYPTO_store_u32_le(out + 12, c->h[3]);
}

}  // namespace

std::array<unsigned char, 16> CalculateMd5Digest(absl::string_view s) {
  MD5_CTX ctx;
  MD5_Init(&ctx);
  MD5_Update(&ctx, s.data(), s.length());
  std::array<unsigned char, MD5_DIGEST_LENGTH> digest;
  MD5_Final(digest.data(), &ctx);
  return digest;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
