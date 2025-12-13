import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashUtils {
  /// Hash password using SHA-256
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Verify password by comparing hashes
  static bool verifyPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }
  
  /// Generate a random anonymous ID
  static String generateAnonymousId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = sha256.convert(utf8.encode(timestamp.toString())).toString();
    return 'User#${hash.substring(0, 4).toUpperCase()}';
  }
}
