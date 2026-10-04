import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:html' as io_or_html;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/user_account.dart';

class AuthDatabase {
  static final AuthDatabase _instance = AuthDatabase._internal();
  factory AuthDatabase() => _instance;
  AuthDatabase._internal();

  Database? _db;
  static const String _dbName = 'loco_railway_users.db';
  static const String _tableName = 'users';
  static const String _salt = 'loco_mumbai_rail_secure_salt_v1';

  static const String _keyActiveIdentifier = 'loco_active_user_identifier';
  static const String _keyIsLoggedIn = 'loco_is_logged_in';
  static const String _keyWebUsers = 'loco_web_users_store';

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database?> _initDatabase() async {
    if (kIsWeb) return null;

    // Desktop initialization for sqflite_common_ffi
    if (!kIsWeb) {
      try {
        // Safe check for desktop platforms
        if (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS) {
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
        }
      } catch (e) {
        debugPrint('SQLite FFI init notice: $e');
      }
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            identifier TEXT NOT NULL UNIQUE,
            phone TEXT,
            email TEXT,
            password_hash TEXT NOT NULL,
            mpin TEXT,
            biometric_enabled INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            last_login TEXT
          )
        ''');
      },
    );
  }

  /// Hashes a plain password with SHA-256 and constant salt
  String hashPassword(String password) {
    final bytes = utf8.encode('$_salt:$password');
    return sha256.convert(bytes).toString();
  }

  /// Normalize phone or email for case-insensitive and clean matching
  String normalizeIdentifier(String raw) {
    return raw.trim().toLowerCase();
  }

  // ================= WEB FALLBACK STORAGE HELPERS =================
  Future<List<UserAccount>> _getWebUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyWebUsers);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => UserAccount.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveWebUsers(List<UserAccount> users) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(users.map((u) => u.toMap()).toList());
    await prefs.setString(_keyWebUsers, encoded);
  }
  // ================================================================

  /// Check if an identifier is registered
  Future<bool> userExists(String rawIdentifier) async {
    final normalized = normalizeIdentifier(rawIdentifier);

    if (kIsWeb) {
      final webUsers = await _getWebUsers();
      return webUsers.any((u) =>
          u.identifier.toLowerCase() == normalized ||
          (u.phone != null && u.phone!.toLowerCase() == normalized) ||
          (u.email != null && u.email!.toLowerCase() == normalized));
    }

    final db = await database;
    if (db == null) return false;

    final results = await db.query(
      _tableName,
      where: 'LOWER(identifier) = ? OR LOWER(phone) = ? OR LOWER(email) = ?',
      whereArgs: [normalized, normalized, normalized],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Register a new user
  Future<UserAccount> registerUser({
    required String name,
    required String identifier,
    String? phone,
    String? email,
    required String password,
    String? mpin,
    bool biometricEnabled = true,
  }) async {
    final normalizedId = normalizeIdentifier(identifier);
    final hashedPassword = hashPassword(password);
    final now = DateTime.now();

    final user = UserAccount(
      name: name.trim(),
      identifier: normalizedId,
      phone: phone?.trim(),
      email: email?.trim(),
      passwordHash: hashedPassword,
      mpin: mpin?.trim(),
      biometricEnabled: biometricEnabled,
      createdAt: now,
      lastLogin: now,
    );

    if (kIsWeb) {
      final webUsers = await _getWebUsers();
      webUsers.removeWhere((u) => u.identifier.toLowerCase() == normalizedId);
      final createdUser = user.copyWith(id: webUsers.length + 1);
      webUsers.add(createdUser);
      await _saveWebUsers(webUsers);
      await setActiveSession(createdUser);
      return createdUser;
    }

    final db = await database;
    final id = await db!.insert(
      _tableName,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final createdUser = user.copyWith(id: id);
    await setActiveSession(createdUser);
    return createdUser;
  }

  /// Retrieve a user by phone, email, or normalized identifier
  Future<UserAccount?> getUserByIdentifier(String rawIdentifier) async {
    final normalized = normalizeIdentifier(rawIdentifier);

    if (kIsWeb) {
      final webUsers = await _getWebUsers();
      try {
        return webUsers.firstWhere((u) =>
            u.identifier.toLowerCase() == normalized ||
            (u.phone != null && u.phone!.toLowerCase() == normalized) ||
            (u.email != null && u.email!.toLowerCase() == normalized));
      } catch (_) {
        return null;
      }
    }

    final db = await database;
    if (db == null) return null;

    final results = await db.query(
      _tableName,
      where: 'LOWER(identifier) = ? OR LOWER(phone) = ? OR LOWER(email) = ?',
      whereArgs: [normalized, normalized, normalized],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return UserAccount.fromMap(results.first);
  }

  /// Authenticate with phone/email and password
  Future<UserAccount?> authenticateWithPassword(String rawIdentifier, String password) async {
    final user = await getUserByIdentifier(rawIdentifier);
    if (user == null) return null;

    final inputHash = hashPassword(password);
    if (user.passwordHash == inputHash) {
      await _recordLogin(user);
      return user;
    }
    return null;
  }

  /// Authenticate with 4-digit MPIN
  Future<UserAccount?> authenticateWithMpin(String mpin, {String? rawIdentifier}) async {
    if (rawIdentifier != null && rawIdentifier.isNotEmpty) {
      final user = await getUserByIdentifier(rawIdentifier);
      if (user != null && user.mpin == mpin.trim()) {
        await _recordLogin(user);
        return user;
      }
      return null;
    }

    // If identifier not provided, match against last active user
    final lastActive = await getLastActiveUser();
    if (lastActive != null && lastActive.mpin == mpin.trim()) {
      await _recordLogin(lastActive);
      return lastActive;
    }

    if (kIsWeb) {
      final webUsers = await _getWebUsers();
      try {
        final match = webUsers.firstWhere((u) => u.mpin == mpin.trim());
        await _recordLogin(match);
        return match;
      } catch (_) {
        return null;
      }
    }

    final db = await database;
    if (db == null) return null;

    final results = await db.query(
      _tableName,
      where: 'mpin = ?',
      whereArgs: [mpin.trim()],
      limit: 1,
    );

    if (results.isNotEmpty) {
      final user = UserAccount.fromMap(results.first);
      await _recordLogin(user);
      return user;
    }
    return null;
  }

  /// Update password (used for Forgot Password / Reset Password)
  Future<bool> updatePassword(String rawIdentifier, String newPassword) async {
    final normalized = normalizeIdentifier(rawIdentifier);
    final newHash = hashPassword(newPassword);

    if (kIsWeb) {
      final webUsers = await _getWebUsers();
      final idx = webUsers.indexWhere((u) =>
          u.identifier.toLowerCase() == normalized ||
          (u.phone != null && u.phone!.toLowerCase() == normalized) ||
          (u.email != null && u.email!.toLowerCase() == normalized));
      if (idx == -1) return false;
      webUsers[idx] = webUsers[idx].copyWith(passwordHash: newHash);
      await _saveWebUsers(webUsers);
      return true;
    }

    final db = await database;
    if (db == null) return false;

    final count = await db.update(
      _tableName,
      {'password_hash': newHash},
      where: 'LOWER(identifier) = ? OR LOWER(phone) = ? OR LOWER(email) = ?',
      whereArgs: [normalized, normalized, normalized],
    );

    return count > 0;
  }

  /// Update 4-digit MPIN
  Future<bool> updateMpin(String rawIdentifier, String newMpin) async {
    final normalized = normalizeIdentifier(rawIdentifier);

    if (kIsWeb) {
      final webUsers = await _getWebUsers();
      final idx = webUsers.indexWhere((u) =>
          u.identifier.toLowerCase() == normalized ||
          (u.phone != null && u.phone!.toLowerCase() == normalized) ||
          (u.email != null && u.email!.toLowerCase() == normalized));
      if (idx != -1) {
        webUsers[idx] = webUsers[idx].copyWith(mpin: newMpin.trim());
        await _saveWebUsers(webUsers);
      }
    } else {
      final db = await database;
      if (db != null) {
        await db.update(
          _tableName,
          {'mpin': newMpin.trim()},
          where: 'LOWER(identifier) = ? OR LOWER(phone) = ? OR LOWER(email) = ?',
          whereArgs: [normalized, normalized, normalized],
        );
      }
    }

    // Sync to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mpin', newMpin.trim());
    await prefs.setBool('isRegistered', true);

    return true;
  }

  /// Toggle or update biometric authentication permission
  Future<bool> setBiometricEnabled(String rawIdentifier, bool enabled) async {
    final normalized = normalizeIdentifier(rawIdentifier);

    if (kIsWeb) {
      final webUsers = await _getWebUsers();
      final idx = webUsers.indexWhere((u) =>
          u.identifier.toLowerCase() == normalized ||
          (u.phone != null && u.phone!.toLowerCase() == normalized) ||
          (u.email != null && u.email!.toLowerCase() == normalized));
      if (idx != -1) {
        webUsers[idx] = webUsers[idx].copyWith(biometricEnabled: enabled);
        await _saveWebUsers(webUsers);
      }
    } else {
      final db = await database;
      if (db != null) {
        await db.update(
          _tableName,
          {'biometric_enabled': enabled ? 1 : 0},
          where: 'LOWER(identifier) = ? OR LOWER(phone) = ? OR LOWER(email) = ?',
          whereArgs: [normalized, normalized, normalized],
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);

    return true;
  }

  /// Record user last login timestamp
  Future<void> _recordLogin(UserAccount user) async {
    final now = DateTime.now();

    if (kIsWeb) {
      final webUsers = await _getWebUsers();
      final idx = webUsers.indexWhere((u) => u.identifier == user.identifier);
      if (idx != -1) {
        webUsers[idx] = webUsers[idx].copyWith(lastLogin: now);
        await _saveWebUsers(webUsers);
      }
    } else {
      final db = await database;
      if (db != null) {
        await db.update(
          _tableName,
          {'last_login': now.toIso8601String()},
          where: 'id = ?',
          whereArgs: [user.id],
        );
      }
    }

    await setActiveSession(user);
  }

  /// Sets the currently active user session
  Future<void> setActiveSession(UserAccount user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveIdentifier, user.identifier);
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setBool('isRegistered', true);
    if (user.mpin != null) {
      await prefs.setString('mpin', user.mpin!);
    }
    await prefs.setString('userName', user.name);
    await prefs.setString('userPhone', user.phone ?? user.identifier);
    await prefs.setString('userEmail', user.email ?? '');
    await prefs.setBool('biometric_enabled', user.biometricEnabled);
  }

  /// Retrieves the active session user
  Future<UserAccount?> getActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    if (!isLoggedIn) return null;

    final identifier = prefs.getString(_keyActiveIdentifier);
    if (identifier == null) return null;

    return await getUserByIdentifier(identifier);
  }

  /// Retrieves the last active user account (even if logged out, for MPIN or Biometric quick unlock)
  Future<UserAccount?> getLastActiveUser() async {
    final prefs = await SharedPreferences.getInstance();
    final identifier = prefs.getString(_keyActiveIdentifier);
    if (identifier != null) {
      final user = await getUserByIdentifier(identifier);
      if (user != null) return user;
    }

    if (kIsWeb) {
      final webUsers = await _getWebUsers();
      if (webUsers.isNotEmpty) return webUsers.last;
      return null;
    }

    final db = await database;
    if (db == null) return null;

    final results = await db.query(
      _tableName,
      orderBy: 'id DESC',
      limit: 1,
    );
    if (results.isNotEmpty) {
      return UserAccount.fromMap(results.first);
    }
    return null;
  }

  /// Clear active session (Log out)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
  }

  /// Check if any user has registered in database
  Future<bool> hasRegisteredUsers() async {
    if (kIsWeb) {
      final webUsers = await _getWebUsers();
      return webUsers.isNotEmpty;
    }

    final db = await database;
    if (db == null) return false;

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    );
    return (count ?? 0) > 0;
  }
}
