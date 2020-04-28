// Copyright 2019 Gohilla Ltd (https://gohilla.com).
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/utils.dart';
import 'package:noise_protocol/noise_protocol.dart';
import 'package:test/test.dart';

Future<void> main() async {
  test('Local ephemeral keypair is generated by initialize()', () async {
    final protocol = NoiseProtocol(
      handshakePattern: HandshakePattern.xx,
      keyExchangeAlgorithm: NoiseKeyExchangeAlgorithm.x25519,
      cipher: NoiseCipher.chachaPoly,
      hashAlgorithm: NoiseHashAlgorithm.blake2s,
    );
    final state0 = HandshakeState(
      protocol: protocol,
      authenticator: NoiseAuthenticator(),
    );
    await state0.initialize(
      isInitiator: true,
    );
    final state1 = HandshakeState(
      protocol: protocol,
      authenticator: NoiseAuthenticator(),
    );
    await state1.initialize(
      isInitiator: false,
    );
    expect(state0.localStaticKeyPair, isNull);
    expect(state0.localEphemeralKeyPair, isNotNull);
  });

  group('XX handshake', () {
    HandshakeState localState;
    HandshakeState remoteState;
    HandshakeResult localResult;
    HandshakeResult remoteResult;

    Future<void> runHandshake() async {
      final prologue = hexToBytes(
        '4a6f686e2047616c74',
      );
      final localStaticKeyPair = await x25519.newKeyPairFromSeed(PrivateKey(
        hexToBytes(
          'e61ef9919cde45dd5f82166404bd08e38bceb5dfdfded0a34c8df7ed542214d1',
        ),
      ));
      final localEphemeralKeyPair = await x25519.newKeyPairFromSeed(PrivateKey(
        hexToBytes(
          '893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a',
        ),
      ));
      final remoteStaticKeyPair = await x25519.newKeyPairFromSeed(PrivateKey(
        hexToBytes(
          '4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893',
        ),
      ));
      final remoteEphemeralKeyPair = await x25519.newKeyPairFromSeed(PrivateKey(
        hexToBytes(
          'bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b',
        ),
      ));

      final protocol = const NoiseProtocol(
        handshakePattern: HandshakePattern.xx,
        keyExchangeAlgorithm: NoiseKeyExchangeAlgorithm.x25519,
        cipher: NoiseCipher.chachaPoly,
        hashAlgorithm: NoiseHashAlgorithm.blake2s,
      );

      // Buffers for messages
      final messageBuffer = <int>[];
      List<int> sentPayload, receivedPayload;

      // Handshake states
      localState = HandshakeState(
        protocol: protocol,
        authenticator: NoiseAuthenticator(
          localStaticKeyPair: localStaticKeyPair,
          remoteStaticPublicKey: remoteStaticKeyPair.publicKey,
        ),
      );
      remoteState = HandshakeState(
        protocol: protocol,
        authenticator: NoiseAuthenticator(
          localStaticKeyPair: remoteStaticKeyPair,
          remoteStaticPublicKey: localStaticKeyPair.publicKey,
        ),
      );

      // Initialize both parties
      await localState.initialize(
        isInitiator: true,
        prologue: prologue,
        localEphemeralKeyPair: localEphemeralKeyPair,
      );
      await remoteState.initialize(
        isInitiator: false,
        prologue: prologue,
        localEphemeralKeyPair: remoteEphemeralKeyPair,
      );

      // Local state
      expect(
        localState.protocol.toString(),
        'Noise_XX_X25519_ChaChaPoly_BLAKE2s',
      );
      expect(localState.isInitiator, isTrue);
      expect(localState.localStaticKeyPair, localStaticKeyPair);
      expect(localState.localEphemeralKeyPair, localEphemeralKeyPair);
      expect(localState.remoteStaticPublicKey, isNull);
      expect(localState.remoteEphemeralPublicKey, isNull);
      expect(remoteState.symmetricState.cipherState.secretKey, isNull);
      expect(remoteState.symmetricState.cipherState.counter, 0);

      // Remote state
      expect(
        remoteState.protocol.toString(),
        'Noise_XX_X25519_ChaChaPoly_BLAKE2s',
      );
      expect(remoteState.isInitiator, isFalse);
      expect(remoteState.localStaticKeyPair, remoteStaticKeyPair);
      expect(remoteState.localEphemeralKeyPair, remoteEphemeralKeyPair);
      expect(remoteState.remoteStaticPublicKey, isNull);
      expect(remoteState.remoteEphemeralPublicKey, isNull);
      expect(remoteState.symmetricState.cipherState.secretKey, isNull);
      expect(remoteState.symmetricState.cipherState.counter, 0);

      // Shared state
      expect(
        localState.symmetricState.hash,
        remoteState.symmetricState.hash,
      );
      expect(
        localState.symmetricState.cipherState.secretKey,
        remoteState.symmetricState.cipherState.secretKey,
      );
      expect(
        localState.symmetricState.cipherState.counter,
        remoteState.symmetricState.cipherState.counter,
      );

      // -----------------------------
      // NEW MESSAGE: local --> remote
      // -----------------------------

      sentPayload = hexToBytes(
        '4c756477696720766f6e204d69736573',
      );

      // writeMessage(...)
      messageBuffer.clear();
      expect(
        await localState.writeMessage(
          payload: sentPayload,
          messageBuffer: messageBuffer,
        ),
        isNull,
      );
      expect(
        hexFromBytes(messageBuffer),
        hexFromBytes(hexToBytes(
          'ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c79444c756477696720766f6e204d69736573',
        )),
      );

      // readMessage(...)
      receivedPayload = null;
      expect(
        await remoteState.readMessage(
          message: messageBuffer,
          onPayload: (bytes) {
            receivedPayload = bytes;
          },
        ),
        isNull,
      );
      expect(
        hexFromBytes(receivedPayload),
        hexFromBytes(sentPayload),
      );

      // Local state
      expect(localState.localStaticKeyPair, localStaticKeyPair);
      expect(localState.localEphemeralKeyPair, localEphemeralKeyPair);
      expect(localState.remoteStaticPublicKey, isNull);
      expect(localState.remoteEphemeralPublicKey, isNull);
      expect(localState.symmetricState.cipherState.secretKey, isNull);
      expect(localState.symmetricState.cipherState.counter, 0);

      // Remote state
      expect(remoteState.localStaticKeyPair, isNotNull);
      expect(remoteState.localEphemeralKeyPair, isNotNull);
      expect(remoteState.remoteStaticPublicKey, isNull);
      expect(remoteState.remoteEphemeralPublicKey, isNotNull);
      expect(remoteState.symmetricState.cipherState.secretKey, isNull);
      expect(remoteState.symmetricState.cipherState.counter, 0);

      // Shared state
      expect(
        localState.symmetricState.hash,
        remoteState.symmetricState.hash,
      );
      expect(
        localState.symmetricState.cipherState.secretKey,
        remoteState.symmetricState.cipherState.secretKey,
      );
      expect(
        localState.symmetricState.cipherState.counter,
        remoteState.symmetricState.cipherState.counter,
      );

      // -----------------------------
      // NEW MESSAGE: local <-- remote
      // -----------------------------

      sentPayload = hexToBytes(
        '4d757272617920526f746862617264',
      );

      // writeMessage(...)
      messageBuffer.clear();
      expect(
        await remoteState.writeMessage(
          payload: sentPayload,
          messageBuffer: messageBuffer,
        ),
        isNull,
      );
      expect(
        hexFromBytes(messageBuffer),
        hexFromBytes(hexToBytes(
          '95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f1448088437c365eb362a1c991b0557fe8a7fb187d99346765d93ec63db6c1b01504ebeec55a2298d2dbff80eff034d20595153f63a196a6cead1e11b2bb13e336fa13616dd3e8b0a070c882ed3f1a78c7c06c93',
        )),
      );

      // readMessage(...)
      receivedPayload = null;
      expect(
        await localState.readMessage(
          message: messageBuffer,
          onPayload: (bytes) {
            receivedPayload = bytes;
          },
        ),
        isNull,
      );
      expect(
        hexFromBytes(receivedPayload),
        hexFromBytes(sentPayload),
      );

      // Local state
      expect(localState.localStaticKeyPair, isNotNull);
      expect(localState.localEphemeralKeyPair, isNotNull);
      expect(localState.remoteStaticPublicKey, isNotNull);
      expect(localState.remoteEphemeralPublicKey, isNotNull);
      expect(localState.symmetricState.cipherState.secretKey, isNull);
      expect(localState.symmetricState.cipherState.counter, 0);

      // Remote state
      expect(remoteState.symmetricState.cipherState.secretKey, isNotNull);
      expect(remoteState.symmetricState.cipherState.counter, 0);

      // Shared state
      expect(
        localState.symmetricState.hash,
        remoteState.symmetricState.hash,
      );
      expect(
        localState.symmetricState.cipherState.secretKey,
        remoteState.symmetricState.cipherState.secretKey,
      );
      expect(
        localState.symmetricState.cipherState.counter,
        remoteState.symmetricState.cipherState.counter,
      );

      // -----------------------------
      // NEW MESSAGE: local --> remote
      // -----------------------------

      sentPayload = hexToBytes(
        '462e20412e20486179656b',
      );

      // writeMessage(...)
      messageBuffer.clear();
      localResult = await localState.writeMessage(
        payload: sentPayload,
        messageBuffer: messageBuffer,
      );
      expect(
        hexFromBytes(messageBuffer),
        hexFromBytes(hexToBytes(
          '46c3307de83b014258717d97781c1f50936d8b7d50c0722a1739654d10392d415b670c114f79b9a4f80541570f77ce88802efa4220cff733e7b5668ba38059ec904b4b8eef9448085faf51',
        )),
      );

      // readMessage(...)
      receivedPayload = null;
      remoteResult = await remoteState.readMessage(
        message: messageBuffer,
        onPayload: (bytes) {
          receivedPayload = bytes;
        },
      );
      messageBuffer.clear();

      expect(
        hexFromBytes(receivedPayload),
        hexFromBytes(sentPayload),
      );
    }

    test('parties have all keys', () async {
      await runHandshake();
      expect(localResult.encryptingState.secretKey, isNotNull);
      expect(localResult.decryptingState.secretKey, isNotNull);
      expect(remoteResult.encryptingState.secretKey, isNotNull);
      expect(remoteResult.decryptingState.secretKey, isNotNull);
    });

    test('local encrypting key == remote decrypting key', () async {
      await runHandshake();
      final expected = hexToBytes(
        'b2 d1 87 3c 6f 04 7e 32 30 36 7a 28 13 9c c5 99 72 26 3d 1b 07 1d 7f 58 6e b7 5a c1 ea 69 4d 62',
      );
      expect(
        hexFromBytes(localResult.encryptingState.secretKey.extractSync()),
        hexFromBytes(expected),
      );
      expect(
        hexFromBytes(remoteResult.decryptingState.secretKey.extractSync()),
        hexFromBytes(expected),
      );
    });

    test('local decrypting key == remote encrypting key', () async {
      await runHandshake();
      final expected = hexToBytes(
        'e7 19 15 84 2c b9 2f d7 38 98 dd b8 d7 14 c5 cf 79 71 0c 62 03 e5 87 7d be 6f 64 a3 60 c1 8c 95',
      );
      expect(
        hexFromBytes(localResult.decryptingState.secretKey.extractSync()),
        hexFromBytes(expected),
      );
      expect(
        hexFromBytes(remoteResult.encryptingState.secretKey.extractSync()),
        hexFromBytes(expected),
      );
    });

    test('local decrypting key != localencrypting key', () async {
      await runHandshake();
      expect(
        hexFromBytes(
          localResult.encryptingState.secretKey.extractSync(),
        ),
        isNot(hexFromBytes(
          localResult.decryptingState.secretKey.extractSync(),
        )),
      );
    });
  });
}