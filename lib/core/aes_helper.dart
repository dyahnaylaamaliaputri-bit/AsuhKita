import 'package:encrypt/encrypt.dart' as enc;
import 'constants.dart';

class AesHelper {
  static final _key = enc.Key.fromUtf8(AppConstants.aesSecretKey.padRight(32, '*').substring(0, 32));
  static final _iv = enc.IV.fromUtf8('AsuhKitaFixedIV1');

  static String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  static String decrypt(String cipherText) {
    if (cipherText.isEmpty) return '';
    try {
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decrypt64(cipherText, iv: _iv);
      return decrypted;
    } catch (e) {
      return cipherText;
    }
  }
}
