//
//  Shader.metal
//  blocks
//
//  Created by よういち on 2023/09/21.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//
#include <metal_stdlib>
#include "Hash.h"

using namespace metal;

/*
 Radix: 256 (0b100000000)   0x10
 
 Make Adding {incrementValue} into Data[UInt8]({index}) as Radix 256 digits as Little Endian with Detecting Overflow Recursively.
 */
void increment(int64_t index, uint8_t incrementValue, device uint8_t* self, device int64_t& selfLength) {
    uint64_t incrementedByte = self[index] + incrementValue;

    self[index] = incrementedByte & 0b11111111;
    
    if ((incrementedByte & 0b1111111100000000) != 0) {
        uint8_t incrementValue = uint8_t((incrementedByte >> 8) & 0b11111111);
        increment(index + 1, incrementValue, self, selfLength);
    }
}

void add(uint64_t exponent, device uint8_t* newSelf, device int64_t& newSelfLength) {
    int64_t index = int64_t(exponent / uint64_t(8));
    uint8_t remainder = uint8_t(0b01 << (exponent - index*8));
    increment(index, remainder, newSelf, newSelfLength);
}

/*
 Compute Function
 
 Passes as Reference:
 constant float2& res[[buffer(0)]],                 コピーではなく同じ変数を受け取る

 Passes as Address:
 uint64_t* addingExponent       [[ buffer(0) ]],    コピーされたアドレスを受け取る     ←アドレス操作をする場合に使う

 Passes as Value:
 int a                                              コピーされた値を受け取る
 */
kernel void testFunction(device uint64_t& addingExponent       [[ buffer(0) ]],
                         device uint8_t* candidateNonce  [[ buffer(1) ]],
                         device int64_t& candidateNonceLength  [[ buffer(2) ]],  //appended
                         device uint64_t& fixExponent          [[ buffer(3) ]],
                         device bool& foundNonce           [[ buffer(4) ]],
                         constant uint8_t& preNonceAsData       [[ buffer(5) ]],
                         uint thread_position_in_grid [[thread_position_in_grid]] // Gridにおけるthreadの位置
                         ) {
//    Log("\(String(describing: fixExponent)) 候補目")
//    Dump(candidateNonceValue)
//    LogEssential("+ 2^\(addingExponent)")
    add(addingExponent, candidateNonce, candidateNonceLength); //この関数はDataをLittle Endianとして扱っている
    device uint8_t* addedValue = candidateNonce;
    
//    Dump(addedValue)
    char digest[SHA512_DIGEST_STRING_LENGTH];
    thread char* hashedComputedData = SHA512_Data(&preNonceAsData, 64, digest);

//    Log("Hashed.")
//    Dump(hashedComputedData)  //7b54b668 36c1fbdd 13d2441d 9e1434dc 62ca677f b68f5fe6 6a464baa decdbd00 576f8d6b 5ac3bcc8 0844b7d5 0b1cc660 3444bbe7 cfcf8fc0 aa1ee3c6 36d9e339
    char hashedComputedAsChar[SHA512_DIGEST_STRING_LENGTH];
    MEMCPY_BCOPY_ON_THREAD(hashedComputedAsChar, hashedComputedData, SHA512_DIGEST_STRING_LENGTH);
    uint8_t difficultyAsUseExclusiveOR = uint8_t(0);
    bool found = *hashedComputedData ^ difficultyAsUseExclusiveOR;
    if (found) {
//        Log("Nonce発見")
//        Log("\(String(describing: fixExponent)) 候補 + 2^\(addingExponent)")
//        Log("computed Nonce")
        candidateNonce = addedValue;
//        Dump(candidateNonceValue)
//        Dump(hashedComputedData)
        foundNonce = found;
    } else {
        if (addingExponent < NonceBits) {
//            Log("次の桁へ")
        } else {
            /*
             move to 'for in' loop
             */
        }
    }
}
