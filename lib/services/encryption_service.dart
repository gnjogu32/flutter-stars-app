import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _storage = const FlutterSecureStorage();
  final _firestore = FirebaseFirestore.instance;
  final _algorithm = X25519();
  final _cipher = AesGcm.with256bits();

  // Securely store/retrieve identity keys
  static const _privateKeyStorageKey = 'chat_e2ee_private_key';

  Future<void> ensureKeysGenerated(String userId) async {
    final existingKey = await _storage.read(key: _privateKeyStorageKey);
    if (existingKey == null) {
      final keyPair = await _algorithm.newKeyPair();
      final privateKey = await keyPair.extractPrivateKeyBytes();
      final publicKey = await keyPair.extractPublicKey();

      await _storage.write(
        key: _privateKeyStorageKey,
        value: base64Encode(privateKey),
      );

      await _firestore.collection('user_keys').doc(userId).set({
        'publicKey': base64Encode(publicKey.bytes),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String?> getRecipientPublicKey(String recipientId) async {
    try {
      final doc = await _firestore
          .collection('user_keys')
          .doc(recipientId)
          .get();
      return doc.data()?['publicKey'] as String?;
    } catch (e) {
      debugPrint('Error fetching public key: $e');
      return null;
    }
  }

  Future<Map<String, String>> encryptMessage({
    required String content,
    required String recipientPublicKeyBase64,
  }) async {
    final privateKeyBase64 = await _storage.read(key: _privateKeyStorageKey);
    if (privateKeyBase64 == null) throw Exception('Identity keys not found');

    final keyPair = await _algorithm.newKeyPairFromSeed(
      base64Decode(privateKeyBase64),
    );
    final privateKey = await keyPair.extract();

    final recipientPublicKey = SimplePublicKey(
      base64Decode(recipientPublicKeyBase64),
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _algorithm.sharedSecretKey(
      keyPair: privateKey,
      remotePublicKey: recipientPublicKey,
    );

    final secretBytes = await sharedSecret.extractBytes();
    final secretKey = await _cipher.newSecretKeyFromBytes(secretBytes);

    final nonce = _cipher.newNonce();
    final secretBox = await _cipher.encrypt(
      utf8.encode(content),
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'content': base64Encode(secretBox.concatenation()),
      'nonce': base64Encode(secretBox.nonce),
    };
  }

  Future<String> decryptMessage({
    required String encryptedContent,
    required String nonceBase64,
    required String senderPublicKeyBase64,
  }) async {
    final privateKeyBase64 = await _storage.read(key: _privateKeyStorageKey);
    if (privateKeyBase64 == null) return '[Decryption Error: Keys Missing]';

    try {
      final keyPair = await _algorithm.newKeyPairFromSeed(
        base64Decode(privateKeyBase64),
      );
      final privateKey = await keyPair.extract();

      final senderPublicKey = SimplePublicKey(
        base64Decode(senderPublicKeyBase64),
        type: KeyPairType.x25519,
      );

      final sharedSecret = await _algorithm.sharedSecretKey(
        keyPair: privateKey,
        remotePublicKey: senderPublicKey,
      );

      final secretBytes = await sharedSecret.extractBytes();
      final secretKey = await _cipher.newSecretKeyFromBytes(secretBytes);

      final concatenation = base64Decode(encryptedContent);

      // cryptography's SecretBox.concatenation() usually appends MAC at the end
      final macLength = _cipher.macAlgorithm.macLength;
      if (concatenation.length < macLength) {
        throw Exception('Invalid ciphertext');
      }

      final cipherText = concatenation.sublist(
        0,
        concatenation.length - macLength,
      );
      final macBytes = concatenation.sublist(concatenation.length - macLength);

      final secretBox = SecretBox(
        cipherText,
        nonce: base64Decode(nonceBase64),
        mac: Mac(macBytes),
      );

      final clearTextBytes = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(clearTextBytes);
    } catch (e) {
      debugPrint('Decryption failed: $e');
      return '[Encrypted Message]';
    }
  }
}
