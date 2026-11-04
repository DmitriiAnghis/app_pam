import 'package:flutter/foundation.dart';
import '../data/product.dart';
import '../data/product_repository.dart';
import '../data/result.dart';

class ProductsModel extends ChangeNotifier {
  ProductsModel(this._repository);

  final ProductRepository _repository;

  static const _limit = 20;

  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _search;
  String? _error;
  List<Product> _products = const [];

  bool get isLoading => _loading;
  bool get hasMore => _hasMore;
  String? get search => _search;
  String? get error => _error;
  List<Product> get products => List.unmodifiable(_products);

  int get lowStockCount => _products.where((p) => p.quantity < 10).length;

  Future<void> load({String? search}) async {
    _search = search ?? _search;
    _page = 1;
    _loading = true;
    _error = null;
    notifyListeners();
    await _fetch();
    _loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _fetch();
    notifyListeners();
  }

  Future<void> _fetch() async {
    switch (await _repository.fetchAll(limit: _limit, search: _search)) {
      case Ok(:final value):
        _products = value;
        _page = 1;
        _hasMore = value.length == _limit;
        _error = null;
      case Err(:final msg):
        _error = msg;
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || _loading || !_hasMore) return;
    _loadingMore = true;
    final result = await _repository.fetchAll(
        page: _page + 1, limit: _limit, search: _search);
    switch (result) {
      case Ok(:final value):
        _page += 1;
        _products = [..._products, ...value];
        _hasMore = value.length == _limit;
      case Err():
        _hasMore = false;
    }
    _loadingMore = false;
    notifyListeners();
  }

  Product? byId(int id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Product> inLocation(int locationId) =>
      _products.where((p) => p.locationId == locationId).toList();

  Future<String?> remove(int id) async {
    switch (await _repository.delete(id)) {
      case Ok():
        _products = _products.where((p) => p.id != id).toList();
        notifyListeners();
        return null;
      case Err(:final msg):
        return msg;
    }
  }
}
