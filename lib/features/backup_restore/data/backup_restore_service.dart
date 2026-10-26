import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

class BackupRestoreService {
  BackupRestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const int _schemaVersion = 1;

  static const List<String> _userCollections = [
    'transactions',
    'budgets',
    'wallets',
    'bills',
    'categories',
    'recurring_transactions',
  ];

  User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User is not authenticated.');
    }
    return user;
  }

  Future<Map<String, dynamic>> buildBackup() async {
    final user = _user;
    final data = <String, dynamic>{};

    for (final collectionName in _userCollections) {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection(collectionName)
          .get();

      data[collectionName] = snapshot.docs
          .map(
            (doc) => {
              'id': doc.id,
              'data': _encodeValue(doc.data()),
            },
          )
          .toList();
    }

    final goalsSnapshot = await _firestore
        .collection('savings_goals')
        .where('userId', isEqualTo: user.uid)
        .get();

    data['savings_goals'] = goalsSnapshot.docs
        .map(
          (doc) => {
            'id': doc.id,
            'data': _encodeValue(doc.data()),
          },
        )
        .toList();

    return {
      'app': 'MoneyFlow',
      'schemaVersion': _schemaVersion,
      'userId': user.uid,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };
  }

  Future<String?> saveBackupFile() async {
    final backup = await buildBackup();
    final bytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(backup),
    );

    final path = await FilePicker.saveFile(
      dialogTitle: 'Save MoneyFlow Backup',
      fileName: 'moneyflow_backup_${_dateStamp()}.json',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    return path?.toString();
  }

  Future<RestoreSummary?> pickAndRestore() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    if (picked == null) {
      return null;
    }

    final bytes = await picked.readAsBytes();
    final text = utf8.decode(bytes);

    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('The selected file is not valid JSON.');
    }

    if (decoded is! Map) {
      throw const FormatException('Invalid MoneyFlow backup format.');
    }

    final backup = Map<String, dynamic>.from(decoded);
    _validateBackup(backup);

    final backupUserId = backup['userId']?.toString();
    if (backupUserId != _user.uid) {
      throw const FormatException(
        'This backup belongs to a different account.',
      );
    }

    final rawData = backup['data'];
    if (rawData is! Map) {
      throw const FormatException('Backup data is missing.');
    }

    final data = Map<String, dynamic>.from(rawData);
    final counts = <String, int>{};

    for (final collectionName in _userCollections) {
      counts[collectionName] = await _restoreUserCollection(
        collectionName,
        data[collectionName],
      );
    }

    counts['savings_goals'] = await _restoreSavingsGoals(
      data['savings_goals'],
    );

    return RestoreSummary(
      counts: counts,
      backupCreatedAt: backup['createdAt']?.toString(),
    );
  }

  Future<int> _restoreUserCollection(
    String collectionName,
    dynamic rawItems,
  ) async {
    if (rawItems == null) {
      return 0;
    }

    if (rawItems is! List) {
      throw FormatException(
        'Invalid $collectionName section in backup.',
      );
    }

    final collection = _firestore
        .collection('users')
        .doc(_user.uid)
        .collection(collectionName);

    return _restoreDocuments(collection, rawItems);
  }

  Future<int> _restoreSavingsGoals(dynamic rawItems) async {
    if (rawItems == null) {
      return 0;
    }

    if (rawItems is! List) {
      throw const FormatException(
        'Invalid savings_goals section in backup.',
      );
    }

    final collection = _firestore.collection('savings_goals');

    return _restoreDocuments(collection, rawItems);
  }

  Future<int> _restoreDocuments(
    CollectionReference<Map<String, dynamic>> collection,
    List<dynamic> rawItems,
  ) async {
    final normalized = <Map<String, dynamic>>[];

    for (final item in rawItems) {
      if (item is! Map) {
        throw const FormatException('Invalid document entry in backup.');
      }

      final map = Map<String, dynamic>.from(item);
      final id = map['id']?.toString() ?? '';
      final rawDocument = map['data'];

      if (id.isEmpty || rawDocument is! Map) {
        throw const FormatException('Invalid document structure in backup.');
      }

      final document = Map<String, dynamic>.from(rawDocument);
      normalized.add({
        'id': id,
        'data': _decodeValue(document),
      });
    }

    var restored = 0;
    WriteBatch? batch;
    var writesInBatch = 0;

    Future<void> flush() async {
      if (batch == null || writesInBatch == 0) {
        return;
      }

      await batch!.commit();
      batch = null;
      writesInBatch = 0;
    }

    for (final item in normalized) {
      batch ??= _firestore.batch();

      final id = item['id'] as String;
      final document = Map<String, dynamic>.from(
        item['data'] as Map,
      );

      batch!.set(
        collection.doc(id),
        document,
        SetOptions(merge: false),
      );

      writesInBatch++;
      restored++;

      // Firestore allows at most 500 writes in a batch.
      if (writesInBatch == 450) {
        await flush();
      }
    }

    await flush();
    return restored;
  }

  void _validateBackup(Map<String, dynamic> backup) {
    if (backup['app'] != 'MoneyFlow') {
      throw const FormatException('This is not a MoneyFlow backup.');
    }

    final schemaVersion = backup['schemaVersion'];
    if (schemaVersion is! num ||
        schemaVersion.toInt() != _schemaVersion) {
      throw const FormatException(
        'This backup version is not supported by this app version.',
      );
    }

    if (backup['userId'] == null ||
        backup['userId'].toString().trim().isEmpty) {
      throw const FormatException('Backup account information is missing.');
    }
  }

  dynamic _encodeValue(dynamic value) {
    if (value is Timestamp) {
      return {
        '__moneyflowType': 'timestamp',
        'value': value.toDate().toUtc().toIso8601String(),
      };
    }

    if (value is DateTime) {
      return {
        '__moneyflowType': 'timestamp',
        'value': value.toUtc().toIso8601String(),
      };
    }

    if (value is GeoPoint) {
      return {
        '__moneyflowType': 'geopoint',
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }

    if (value is DocumentReference) {
      return {
        '__moneyflowType': 'reference',
        'path': value.path,
      };
    }

    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(
          key.toString(),
          _encodeValue(item),
        ),
      );
    }

    if (value is Iterable) {
      return value.map(_encodeValue).toList();
    }

    return value;
  }

  dynamic _decodeValue(dynamic value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final type = map['__moneyflowType'];

      if (type == 'timestamp') {
        final raw = map['value']?.toString();
        if (raw == null) {
          throw const FormatException('Invalid timestamp in backup.');
        }
        return Timestamp.fromDate(DateTime.parse(raw).toLocal());
      }

      if (type == 'geopoint') {
        final latitude = (map['latitude'] as num?)?.toDouble();
        final longitude = (map['longitude'] as num?)?.toDouble();
        if (latitude == null || longitude == null) {
          throw const FormatException('Invalid GeoPoint in backup.');
        }
        return GeoPoint(latitude, longitude);
      }

      if (type == 'reference') {
        final path = map['path']?.toString();
        if (path == null || path.isEmpty) {
          throw const FormatException(
            'Invalid document reference in backup.',
          );
        }
        return _firestore.doc(path);
      }

      return map.map(
        (key, item) => MapEntry(
          key,
          _decodeValue(item),
        ),
      );
    }

    if (value is List) {
      return value.map(_decodeValue).toList();
    }

    return value;
  }

  String _dateStamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');

    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}

class RestoreSummary {
  const RestoreSummary({
    required this.counts,
    required this.backupCreatedAt,
  });

  final Map<String, int> counts;
  final String? backupCreatedAt;

  int get totalDocuments =>
      counts.values.fold<int>(0, (total, count) => total + count);
}
