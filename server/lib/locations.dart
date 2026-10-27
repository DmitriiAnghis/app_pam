
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'db.dart';
import 'errors.dart';

const _select = '''
  SELECT l.*, COALESCE(SUM(p.quantity), 0) AS used, COUNT(p.id) AS item_count
  FROM locations l LEFT JOIN products p ON p.location_id = l.id
''';

Map<String, Object?> _toJson(Row row) => {
      'id': row['id'],
      'code': row['code'],
      'zone': row['zone'],
      'capacity': row['capacity'],
      'used': row['used'],
      'itemCount': row['item_count'],
    };

Row? _find(String? idParam) {
  final id = int.tryParse(idParam ?? '');
  if (id == null) return null;
  final rows = db.select('$_select WHERE l.id = ? GROUP BY l.id', [id]);
  return rows.isEmpty ? null : rows.first;
}

Future<Response> listLocations(Request request) async {
  final query = request.url.queryParameters;
  final page = max(int.tryParse(query['page'] ?? '') ?? 1, 1);
  final limit = (int.tryParse(query['limit'] ?? '') ?? 20).clamp(1, 100);
  final args = ['%${query['search'] ?? ''}%'];

  final total = db
      .select('SELECT COUNT(*) AS n FROM locations WHERE code LIKE ?', args)
      .first['n'] as int;
  final rows = db.select(
    '$_select WHERE l.code LIKE ? GROUP BY l.id ORDER BY l.code LIMIT ? OFFSET ?',
    [...args, limit, (page - 1) * limit],
  );

  return jsonResponse({
    'items': rows.map(_toJson).toList(),
    'page': page,
    'limit': limit,
    'total': total,
  });
}

Object _fields(Map<String, dynamic> body) {
  final code = stringField(body, 'code');
  final zone = stringField(body, 'zone');
  final capacity = body['capacity'];
  if (code == null) return 'code is required';
  if (zone == null) return 'zone is required';
  if (capacity is! int || capacity <= 0) {
    return 'capacity must be a positive integer';
  }
  return [code, zone, capacity];
}

Future<Response> createLocation(Request request) async {
  final body = await readJsonBody(request);
  if (body == null) return validationError('Body must be a JSON object');
  final f = _fields(body);
  if (f is String) return validationError(f);
  if (db.select('SELECT id FROM locations WHERE code = ?', [(f as List)[0]])
      .isNotEmpty) {
    return validationError('code must be unique');
  }
  db.execute(
      'INSERT INTO locations (code, zone, capacity) VALUES (?, ?, ?)', f);
  return jsonResponse(_toJson(_find('${db.lastInsertRowId}')!), status: 201);
}

Future<Response> getLocation(Request request) async {
  final row = _find(request.params['id']);
  if (row == null) return notFound('Location not found');
  return jsonResponse(_toJson(row));
}

Future<Response> updateLocation(Request request) async {
  final row = _find(request.params['id']);
  if (row == null) return notFound('Location not found');
  final body = await readJsonBody(request);
  if (body == null) return validationError('Body must be a JSON object');
  final f = _fields(body);
  if (f is String) return validationError(f);
  db.execute('UPDATE locations SET code = ?, zone = ?, capacity = ? WHERE id = ?',
      [...(f as List), row['id']]);
  return jsonResponse(_toJson(_find('${row['id']}')!));
}

Future<Response> deleteLocation(Request request) async {
  final row = _find(request.params['id']);
  if (row == null) return notFound('Location not found');
  if ((row['item_count'] as int) > 0) {
    return validationError('Location is not empty');
  }
  db.execute('DELETE FROM locations WHERE id = ?', [row['id']]);
  return Response(204);
}
