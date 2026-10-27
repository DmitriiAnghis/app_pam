
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'auth.dart';
import 'db.dart';
import 'errors.dart';

const _types = ['receipt', 'shipment', 'transfer'];

Map<String, Object?> _toJson(Row row) => {
      'id': row['id'],
      'productId': row['product_id'],
      'type': row['type'],
      'quantity': row['quantity'],
      'fromLocationId': row['from_location_id'],
      'toLocationId': row['to_location_id'],
      'userId': row['user_id'],
      'note': row['note'],
      'createdAt': row['created_at'],
    };

Row? _find(String? idParam) {
  final id = int.tryParse(idParam ?? '');
  if (id == null) return null;
  final rows = db.select('SELECT * FROM stock_movements WHERE id = ?', [id]);
  return rows.isEmpty ? null : rows.first;
}

bool _locationExists(Object? id) =>
    id is int &&
    db.select('SELECT id FROM locations WHERE id = ?', [id]).isNotEmpty;

Future<Response> listStockMovements(Request request) async {
  final query = request.url.queryParameters;
  final page = max(int.tryParse(query['page'] ?? '') ?? 1, 1);
  final limit = (int.tryParse(query['limit'] ?? '') ?? 20).clamp(1, 100);

  var where = '1 = 1';
  final args = <Object?>[];
  if (_types.contains(query['type'])) {
    where += ' AND type = ?';
    args.add(query['type']);
  }
  final productId = int.tryParse(query['productId'] ?? '');
  if (productId != null) {
    where += ' AND product_id = ?';
    args.add(productId);
  }

  final total =
      db.select('SELECT COUNT(*) AS n FROM stock_movements WHERE $where', args)
          .first['n'] as int;
  final rows = db.select(
    'SELECT * FROM stock_movements WHERE $where '
    'ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?',
    [...args, limit, (page - 1) * limit],
  );

  return jsonResponse({
    'items': rows.map(_toJson).toList(),
    'page': page,
    'limit': limit,
    'total': total,
  });
}

Future<Response> createStockMovement(Request request) async {
  final body = await readJsonBody(request);
  if (body == null) return validationError('Body must be a JSON object');
  final type = body['type'];
  final quantity = body['quantity'];
  final productId = body['productId'];
  final from = body['fromLocationId'];
  final to = body['toLocationId'];
  final note = body['note'] is String ? (body['note'] as String).trim() : '';

  if (!_types.contains(type)) {
    return validationError('type must be receipt, shipment or transfer');
  }
  if (quantity is! int || quantity <= 0) {
    return validationError('quantity must be a positive integer');
  }
  final products = productId is int
      ? db.select('SELECT * FROM products WHERE id = ?', [productId])
      : <Row>[];
  if (products.isEmpty) return validationError('productId does not exist');
  if (type != 'receipt' && !_locationExists(from)) {
    return validationError('fromLocationId is required');
  }
  if (type != 'shipment' && !_locationExists(to)) {
    return validationError('toLocationId is required');
  }
  if (type != 'receipt' && quantity > (products.first['quantity'] as int)) {
    return validationError('Not enough stock');
  }

  db.execute('BEGIN');
  switch (type) {
    case 'receipt':
      db.execute(
          'UPDATE products SET quantity = quantity + ?, location_id = ? '
          'WHERE id = ?',
          [quantity, to, productId]);
    case 'shipment':
      db.execute('UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [quantity, productId]);
    case 'transfer':
      db.execute('UPDATE products SET location_id = ? WHERE id = ?',
          [to, productId]);
  }
  db.execute(
    'INSERT INTO stock_movements (product_id, type, quantity, from_location_id, '
    'to_location_id, user_id, note, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    [
      productId, type, quantity,
      type == 'receipt' ? null : from,
      type == 'shipment' ? null : to,
      currentUserId(request), note, nowIso(),
    ],
  );
  final id = db.lastInsertRowId;
  db.execute('COMMIT');
  return jsonResponse(_toJson(_find('$id')!), status: 201);
}

Future<Response> getStockMovement(Request request) async {
  final row = _find(request.params['id']);
  if (row == null) return notFound('Stock movement not found');
  return jsonResponse(_toJson(row));
}

Future<Response> deleteStockMovement(Request request) async {
  final row = _find(request.params['id']);
  if (row == null) return notFound('Stock movement not found');
  db.execute('DELETE FROM stock_movements WHERE id = ?', [row['id']]);
  return Response(204);
}
