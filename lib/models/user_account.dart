class UserAccount {
  final int? id;
  final String name;
  final String identifier; // Primary login key: normalized phone number or email
  final String? phone;
  final String? email;
  final String passwordHash;
  final String? mpin;
  final bool biometricEnabled;
  final DateTime createdAt;
  final DateTime? lastLogin;

  const UserAccount({
    this.id,
    required this.name,
    required this.identifier,
    this.phone,
    this.email,
    required this.passwordHash,
    this.mpin,
    this.biometricEnabled = true,
    required this.createdAt,
    this.lastLogin,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'identifier': identifier,
      'phone': phone,
      'email': email,
      'password_hash': passwordHash,
      'mpin': mpin,
      'biometric_enabled': biometricEnabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  factory UserAccount.fromMap(Map<String, dynamic> map) {
    return UserAccount(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      identifier: map['identifier'] as String? ?? '',
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      passwordHash: map['password_hash'] as String? ?? '',
      mpin: map['mpin'] as String?,
      biometricEnabled: (map['biometric_enabled'] as int? ?? 1) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastLogin: map['last_login'] != null
          ? DateTime.tryParse(map['last_login'] as String)
          : null,
    );
  }

  UserAccount copyWith({
    int? id,
    String? name,
    String? identifier,
    String? phone,
    String? email,
    String? passwordHash,
    String? mpin,
    bool? biometricEnabled,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      identifier: identifier ?? this.identifier,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      mpin: mpin ?? this.mpin,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
