import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/digests/sha256.dart';

class SimpleEncryptor {
  static String encode(String plainText, String password) {
    final key = _initKey(password);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.ecb));
    return encrypter.encrypt(plainText).base64;
  }

  static String decrypt(String encryptedBase64, String password) {
    final key = _initKey(password);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.ecb));
    return encrypter.decrypt64(encryptedBase64);
  }

  static encrypt.Key _initKey(String password) {
    final uint8Password = Uint8List.fromList(utf8.encode(password));
    final digest = SHA256Digest().process(uint8Password);
    return encrypt.Key(digest);
  }
}
