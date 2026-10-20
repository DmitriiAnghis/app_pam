import 'package:flutter/foundation.dart';
import '../data/product.dart';
import '../data/product_repository.dart';
import '../data/result.dart';

class ProductsModel extends ChangeNotifier {
  ProductsModel(this._repository);

  final ProductRepository _repository;

  bool _loading = false;
  String? _error;
  List<Product> _products = const [];

  bool get isLoading => _loading;
  String? get error => _error;
  List<Product> get products => List.unmodifiable(_products);

  int get lowStockCount => _products.where((p) => p.quantity < 10).length;

  Future<void> load() async {
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
    switch (await _repository.fetchAll()) {
      case Ok(:final value):
        _products = value;
        _error = null;
      case Err(:final msg):
        _error = msg;
    }
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
