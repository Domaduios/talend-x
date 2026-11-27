import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

extension SupabaseUserCompat on User {
  String get uid => id;
}

extension DateTimeToDateCompat on DateTime {
  DateTime toDate() => this;
}

typedef Query = DbQuery;

/// Translates Firestore-style collection/field operations to real Supabase
/// PostgreSQL queries and Realtime streams on the dedicated Talend X project.
class SupabaseDb {
  static final SupabaseDb instance = SupabaseDb._();
  SupabaseDb._();

  static const Map<String, String> _tableMap = {
    'paymentMethods': 'payment_methods',
  };

  static const Map<String, String> _camelToSnake = {
    'firebaseUid': 'firebase_uid',
    'isAdmin': 'is_admin',
    'profileCompleted': 'profile_completed',
    'emailVerified': 'email_verified',
    'teachSkills': 'teach_skills',
    'learnSkills': 'learn_skills',
    'recentSearches': 'recent_searches',
    'createdAt': 'created_at',
    'updatedAt': 'updated_at',
    'userId': 'user_id',
    'favoriteUserId': 'favorite_user_id',
    'senderId': 'sender_id',
    'receiverId': 'receiver_id',
    'requesterId': 'requester_id',
    'recipientId': 'recipient_id',
    'teacherId': 'teacher_id',
    'learnerId': 'learner_id',
    'scheduledAt': 'scheduled_at',
    'durationMinutes': 'duration_minutes',
    'reviewerId': 'reviewer_id',
    'revieweeId': 'reviewee_id',
    'communityId': 'community_id',
    'createdBy': 'created_by',
    'joinedAt': 'joined_at',
    'authorId': 'author_id',
    'ownerId': 'owner_id',
    'isDefault': 'is_default',
    'referrerId': 'referrer_id',
    'referredEmail': 'referred_email',
    'reporterId': 'reporter_id',
    'reportedUserId': 'reported_user_id',
    'blockedUserId': 'blocked_user_id',
  };

  static final Map<String, String> _snakeToCamel = {
    for (final e in _camelToSnake.entries) e.value: e.key,
  };

  static String tableName(String collection) => _tableMap[collection] ?? collection;
  static String toCol(String field) => _camelToSnake[field] ?? field;

  static Map<String, dynamic> toPgRow(Map<String, dynamic> data, {Map<String, dynamic>? existing}) {
    final out = <String, dynamic>{};
    for (final entry in data.entries) {
      final col = toCol(entry.key);
      final val = entry.value;
      if (val is DbFieldOp) {
        if (val.kind == _OpKind.serverTimestamp) {
          out[col] = DateTime.now().toUtc().toIso8601String();
        } else if (val.kind == _OpKind.arrayUnion) {
          final cur = List<dynamic>.from((existing?[col] as List?) ?? const []);
          for (final item in val.items) {
            if (!cur.contains(item)) cur.add(item);
          }
          out[col] = cur;
        } else if (val.kind == _OpKind.arrayRemove) {
          final cur = List<dynamic>.from((existing?[col] as List?) ?? const []);
          cur.removeWhere((e) => val.items.contains(e));
          out[col] = cur;
        } else if (val.kind == _OpKind.increment) {
          final cur = (existing?[col] as num?) ?? 0;
          out[col] = cur + (val.delta ?? 0);
        }
      } else if (val is DateTime) {
        out[col] = val.toUtc().toIso8601String();
      } else {
        out[col] = val;
      }
    }
    return out;
  }

  static Map<String, dynamic> fromPgRow(Map<String, dynamic> row) {
    final out = <String, dynamic>{};
    for (final entry in row.entries) {
      out[entry.key] = entry.value;
      final camel = _snakeToCamel[entry.key];
      if (camel != null) {
        out[camel] = entry.value;
      }
    }
    return out;
  }

  DbCollection collection(String name) => DbCollection(tableName(name));
  DbWriteBatch batch() => DbWriteBatch();
}

enum _OpKind { serverTimestamp, arrayUnion, arrayRemove, increment }

class DbFieldOp {
  final _OpKind kind;
  final List<dynamic> items;
  final num? delta;
  const DbFieldOp._(this.kind, {this.items = const [], this.delta});
}

class DbFieldValue {
  static DbFieldOp serverTimestamp() => const DbFieldOp._(_OpKind.serverTimestamp);
  static DbFieldOp arrayUnion(List<dynamic> elements) => DbFieldOp._(_OpKind.arrayUnion, items: elements);
  static DbFieldOp arrayRemove(List<dynamic> elements) => DbFieldOp._(_OpKind.arrayRemove, items: elements);
  static DbFieldOp increment(num value) => DbFieldOp._(_OpKind.increment, delta: value);
}

DateTime? parseDbDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class Filter {
  final bool Function(Map<String, dynamic> row) _matcher;
  const Filter._(this._matcher);

  factory Filter(
    String field, {
    dynamic isEqualTo,
    dynamic isNotEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    dynamic arrayContains,
    List<dynamic>? arrayContainsAny,
    List<dynamic>? whereIn,
  }) {
    final col = SupabaseDb.toCol(field);
    return Filter._((row) {
      final v = row[col] ?? row[field];
      if (isEqualTo != null && v != isEqualTo) return false;
      if (isNotEqualTo != null && v == isNotEqualTo) return false;
      if (isLessThan != null) {
        if (v is Comparable && isLessThan is Comparable) {
          if (v.compareTo(isLessThan) >= 0) return false;
        } else {
          return false;
        }
      }
      if (isLessThanOrEqualTo != null) {
        if (v is Comparable && isLessThanOrEqualTo is Comparable) {
          if (v.compareTo(isLessThanOrEqualTo) > 0) return false;
        } else {
          return false;
        }
      }
      if (isGreaterThan != null) {
        if (v is Comparable && isGreaterThan is Comparable) {
          if (v.compareTo(isGreaterThan) <= 0) return false;
        } else {
          return false;
        }
      }
      if (isGreaterThanOrEqualTo != null) {
        if (v is Comparable && isGreaterThanOrEqualTo is Comparable) {
          if (v.compareTo(isGreaterThanOrEqualTo) < 0) return false;
        } else {
          return false;
        }
      }
      if (arrayContains != null) {
        if (v is! List || !v.contains(arrayContains)) return false;
      }
      if (arrayContainsAny != null) {
        if (v is! List || !v.any((e) => arrayContainsAny.contains(e))) return false;
      }
      if (whereIn != null && !whereIn.contains(v)) return false;
      return true;
    });
  }

  factory Filter.or(Filter f1, Filter f2, [Filter? f3, Filter? f4, Filter? f5]) {
    final list = [f1, f2, if (f3 != null) f3, if (f4 != null) f4, if (f5 != null) f5];
    return Filter._((row) => list.any((f) => f.matches(row)));
  }

  factory Filter.and(Filter f1, Filter f2, [Filter? f3, Filter? f4, Filter? f5]) {
    final list = [f1, f2, if (f3 != null) f3, if (f4 != null) f4, if (f5 != null) f5];
    return Filter._((row) => list.every((f) => f.matches(row)));
  }

  bool matches(Map<String, dynamic> row) => _matcher(row);
}

enum DocumentChangeType { added, modified, removed }

class DbDocChange {
  final DbDocSnapshot doc;
  final DocumentChangeType type;
  DbDocChange(this.doc, {this.type = DocumentChangeType.modified});
}

class DbDocSnapshot {
  final String id;
  final Map<String, dynamic>? _data;
  final String _table;
  DbDocSnapshot(this.id, this._data, [this._table = '']);
  bool get exists => _data != null;
  Map<String, dynamic> data() => _data ?? const {};
  dynamic operator [](String key) => _data?[key];
  DbDocRef get reference => DbDocRef(_table, id);
}

class DbQuerySnapshot {
  final List<DbDocSnapshot> docs;
  DbQuerySnapshot(this.docs);
  int get size => docs.length;
  bool get isEmpty => docs.isEmpty;
  List<DbDocChange> get docChanges => docs.map((d) => DbDocChange(d)).toList();
}

class DbWriteBatch {
  final List<Future<void> Function()> _ops = [];

  void set(DbDocRef ref, Map<String, dynamic> data, {bool merge = false}) {
    _ops.add(() => ref.set(data, merge: merge));
  }

  void update(DbDocRef ref, Map<String, dynamic> data) {
    _ops.add(() => ref.update(data));
  }

  void delete(DbDocRef ref) {
    _ops.add(() => ref.delete());
  }

  Future<void> commit() async {
    for (final op in _ops) {
      await op();
    }
    _ops.clear();
  }
}

class DbDocRef {
  final String table;
  final String id;
  DbDocRef(this.table, this.id);

  DbCollection collection(String sub) => DbCollection(SupabaseDb.tableName(sub));

  Future<DbDocSnapshot> get() async {
    final row = await SupabaseService.client.from(table).select().eq('id', id).maybeSingle();
    return DbDocSnapshot(id, row == null ? null : SupabaseDb.fromPgRow(row), table);
  }

  Future<void> set(Map<String, dynamic> data, {bool merge = false}) async {
    final existing = merge ? (await get()).data() : null;
    final payload = SupabaseDb.toPgRow(data, existing: existing);
    payload['id'] = id;
    await SupabaseService.client.from(table).upsert(payload);
  }

  Future<void> update(Map<String, dynamic> data) async {
    final needsExisting = data.values.any((v) => v is DbFieldOp && v.kind != _OpKind.serverTimestamp);
    final existing = needsExisting ? (await get()).data() : null;
    final payload = SupabaseDb.toPgRow(data, existing: existing);
    if (payload.isEmpty) return;
    await SupabaseService.client.from(table).update(payload).eq('id', id);
  }

  Future<void> delete() async {
    await SupabaseService.client.from(table).delete().eq('id', id);
  }

  Stream<DbDocSnapshot> snapshots() {
    return SupabaseService.client
        .from(table)
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((rows) => rows.isEmpty
            ? DbDocSnapshot(id, null, table)
            : DbDocSnapshot(id, SupabaseDb.fromPgRow(rows.first), table));
  }
}

class DbQuery {
  final String table;
  final List<({String col, String op, dynamic val})> _filters;
  final List<Filter> _predicates;
  final String? _orderCol;
  final bool _desc;
  final int? _limit;

  DbQuery(
    this.table, {
    List<({String col, String op, dynamic val})> filters = const [],
    List<Filter> predicates = const [],
    String? orderCol,
    bool desc = false,
    int? limit,
  })  : _filters = filters,
        _predicates = predicates,
        _orderCol = orderCol,
        _desc = desc,
        _limit = limit;

  DbQuery where(
    Object fieldOrFilter, {
    dynamic isEqualTo,
    dynamic isNotEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    dynamic arrayContains,
    List<dynamic>? arrayContainsAny,
    List<dynamic>? whereIn,
  }) {
    if (fieldOrFilter is Filter) {
      return DbQuery(
        table,
        filters: _filters,
        predicates: [..._predicates, fieldOrFilter],
        orderCol: _orderCol,
        desc: _desc,
        limit: _limit,
      );
    }
    final field = fieldOrFilter as String;
    final col = SupabaseDb.toCol(field);
    final next = List<({String col, String op, dynamic val})>.from(_filters);
    final nextPreds = List<Filter>.from(_predicates);
    if (isEqualTo != null) next.add((col: col, op: 'eq', val: isEqualTo));
    if (isNotEqualTo != null) next.add((col: col, op: 'neq', val: isNotEqualTo));
    if (isLessThan != null) next.add((col: col, op: 'lt', val: isLessThan));
    if (isLessThanOrEqualTo != null) nextPreds.add(Filter(field, isLessThanOrEqualTo: isLessThanOrEqualTo));
    if (isGreaterThan != null) next.add((col: col, op: 'gt', val: isGreaterThan));
    if (isGreaterThanOrEqualTo != null) nextPreds.add(Filter(field, isGreaterThanOrEqualTo: isGreaterThanOrEqualTo));
    if (arrayContains != null) next.add((col: col, op: 'cs', val: [arrayContains]));
    if (whereIn != null) next.add((col: col, op: 'in', val: whereIn));
    if (arrayContainsAny != null) {
      nextPreds.add(Filter(field, arrayContainsAny: arrayContainsAny));
    }
    return DbQuery(table, filters: next, predicates: nextPreds, orderCol: _orderCol, desc: _desc, limit: _limit);
  }

  DbQuery orderBy(String field, {bool descending = false}) {
    return DbQuery(
      table,
      filters: _filters,
      predicates: _predicates,
      orderCol: SupabaseDb.toCol(field),
      desc: descending,
      limit: _limit,
    );
  }

  DbQuery limit(int count) {
    return DbQuery(table, filters: _filters, predicates: _predicates, orderCol: _orderCol, desc: _desc, limit: count);
  }

  Future<DbQuerySnapshot> get() async {
    dynamic q = SupabaseService.client.from(table).select();
    for (final f in _filters) {
      if (f.op == 'eq') q = q.eq(f.col, f.val);
      else if (f.op == 'neq') q = q.neq(f.col, f.val);
      else if (f.op == 'lt') q = q.lt(f.col, f.val);
      else if (f.op == 'gt') q = q.gt(f.col, f.val);
      else if (f.op == 'cs') q = q.contains(f.col, f.val);
      else if (f.op == 'in') q = q.inFilter(f.col, f.val);
    }
    if (_orderCol != null) q = q.order(_orderCol, ascending: !_desc);
    if (_limit != null && _predicates.isEmpty) q = q.limit(_limit);
    final List<dynamic> rows = await q;
    var docs = rows
        .map((r) => SupabaseDb.fromPgRow(Map<String, dynamic>.from(r as Map)))
        .where((m) => _predicates.every((p) => p.matches(m)))
        .map((m) => DbDocSnapshot((m['id'] ?? '').toString(), m, table))
        .toList();
    if (_limit != null && _predicates.isNotEmpty && docs.length > _limit) {
      docs = docs.take(_limit).toList();
    }
    return DbQuerySnapshot(docs);
  }

  Stream<DbQuerySnapshot> snapshots() {
    dynamic s = SupabaseService.client.from(table).stream(primaryKey: ['id']);
    for (final f in _filters) {
      if (f.op == 'eq') {
        s = s.eq(f.col, f.val);
        break;
      }
    }
    if (_orderCol != null) s = s.order(_orderCol, ascending: !_desc);
    if (_limit != null && _predicates.isEmpty) s = s.limit(_limit);
    return (s as Stream<List<Map<String, dynamic>>>).map((rows) {
      var docs = rows
          .map((r) => SupabaseDb.fromPgRow(r))
          .where((m) {
            for (final f in _filters) {
              final v = m[f.col];
              if (f.op == 'eq' && v != f.val) return false;
              if (f.op == 'neq' && v == f.val) return false;
              if (f.op == 'in' && !(f.val as List).contains(v)) return false;
              if (f.op == 'cs' && !((v as List?) ?? []).contains((f.val as List).first)) return false;
            }
            return _predicates.every((p) => p.matches(m));
          })
          .map((m) => DbDocSnapshot((m['id'] ?? '').toString(), m, table))
          .toList();
      if (_limit != null && _predicates.isNotEmpty && docs.length > _limit) {
        docs = docs.take(_limit).toList();
      }
      return DbQuerySnapshot(docs);
    });
  }
}

class DbCollection extends DbQuery {
  DbCollection(super.table);

  DbDocRef doc([String? id]) => DbDocRef(table, id ?? '');

  Future<DbDocRef> add(Map<String, dynamic> data) async {
    final payload = SupabaseDb.toPgRow(data);
    final inserted = await SupabaseService.client.from(table).insert(payload).select().single();
    return DbDocRef(table, (inserted['id'] ?? '').toString());
  }
}
