
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'db.dart';
import 'errors.dart';

Map<String, Object?> _toJson(Row row) => {
      'id': row['id'],
      'sku': row['sku'],
      'name': row['name'],
      'category': row['category'],
      'unit': row['unit'],
      'quantity': row['quantity'],
      'locationId': row['location_id'],
      'imageUrl': row['image_url'],
    };

Row? _find(String? idParam) {
  final id = int.tryParse(idParam ?? '');
  if (id == null) return null;
  final rows = db.select('SELECT * FROM products WHERE id = ?', [id]);
  return rows.isEmpty ? null : rows.first;
}

bool _locationExists(Object? id) =>
    id is int &&
    db.select('SELECT id FROM locations WHERE id = ?', [id]).isNotEmpty;

Object _fields(Map<String, dynamic> body) {
  final sku = stringField(body, 'sku');
  final name = stringField(body, 'name');
  final category = stringField(body, 'category');
  final unit = stringField(body, 'unit');
  if (sku == null) return 'sku is required';
  if (name == null) return 'name is required';
  if (category == null) return 'category is required';
  if (unit == null) return 'unit is required';
  final quantity = body['quantity'] ?? 0;
  if (quantity is! int || quantity < 0) {
    return 'quantity must be a non-negative integer';
  }
  final locationId = body['locationId'];
  if (locationId != null && !_locationExists(locationId)) {
    return 'locationId does not exist';
  }
  final imageUrl = body['imageUrl'] is String ? body['imageUrl'] as String : '';
  return [sku, name, category, unit, quantity, locationId, imageUrl];
}

Future<Response> listProducts(Request request) async {
  final query = request.url.queryParameters;
  final page = max(int.tryParse(query['page'] ?? '') ?? 1, 1);
  final limit = (int.tryParse(query['limit'] ?? '') ?? 20).clamp(1, 100);
  final search = query['search'] ?? query['q'] ?? '';

  var where = '(lower_u(name) LIKE ? OR lower_u(sku) LIKE ?)';
  final term = '%${search.toLowerCase()}%';
  final args = <Object?>[term, term];
  if ((query['category'] ?? '').isNotEmpty) {
    where += ' AND category = ?';
    args.add(query['category']);
  }
  final locationId = int.tryParse(query['locationId'] ?? '');
  if (locationId != null) {
    where += ' AND location_id = ?';
    args.add(locationId);
  }

  final total =
      db.select('SELECT COUNT(*) AS n FROM products WHERE $where', args)
          .first['n'] as int;
  final rows = db.select(
    'SELECT * FROM products WHERE $where ORDER BY id LIMIT ? OFFSET ?',
    [...args, limit, (page - 1) * limit],
  );

  return jsonResponse({
    'items': rows.map(_toJson).toList(),
    'page': page,
    'limit': limit,
    'total': total,
  });
}

Future<Response> createProduct(Request request) async {
  final body = await readJsonBody(request);
  if (body == null) return validationError('Body must be a JSON object');
  final f = _fields(body);
  if (f is String) return validationError(f);
  if (db.select('SELECT id FROM products WHERE sku = ?',
      [(f as List)[0]]).isNotEmpty) {
    return validationError('sku must be unique');
  }

  db.execute(
    'INSERT INTO products '
    '(sku, name, category, unit, quantity, location_id, image_url) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    f,
  );
  return jsonResponse(_toJson(_find('${db.lastInsertRowId}')!), status: 201);
}

Future<Response> getProduct(Request request) async {
  final row = _find(request.params['id']);
  if (row == null) return notFound('Product not found');
  return jsonResponse(_toJson(row));
}

Future<Response> updateProduct(Request request) async {
  final row = _find(request.params['id']);
  if (row == null) return notFound('Product not found');

  final body = await readJsonBody(request);
  if (body == null) return validationError('Body must be a JSON object');
  final f = _fields(body);
  if (f is String) return validationError(f);
  if (db.select('SELECT id FROM products WHERE sku = ? AND id != ?',
      [(f as List)[0], row['id']]).isNotEmpty) {
    return validationError('sku must be unique');
  }

  db.execute(
    'UPDATE products SET sku = ?, name = ?, category = ?, unit = ?, '
    'quantity = ?, location_id = ?, image_url = ? WHERE id = ?',
    [...f, row['id']],
  );
  return jsonResponse(_toJson(_find('${row['id']}')!));
}

Future<Response> deleteProduct(Request request) async {
  final row = _find(request.params['id']);
  if (row == null) return notFound('Product not found');
  db.execute('DELETE FROM stock_movements WHERE product_id = ?', [row['id']]);
  db.execute('DELETE FROM products WHERE id = ?', [row['id']]);
  return Response(204);
}

Future<Response> placeProduct(Request request) async {
  final row = _find(request.params['id']);
  if (row == null) return notFound('Product not found');
  final body = await readJsonBody(request);
  final locationId = body?['locationId'];
  if (!_locationExists(locationId)) {
    return validationError('locationId does not exist');
  }
  db.execute('UPDATE products SET location_id = ? WHERE id = ?',
      [locationId, row['id']]);
  return jsonResponse(_toJson(_find('${row['id']}')!));
}
