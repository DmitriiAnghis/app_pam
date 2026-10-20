import 'package:flutter/foundation.dart';
import '../data/movement_repository.dart';
import '../data/result.dart';
import '../data/stock_movement.dart';

class MovementsModel extends ChangeNotifier {
  MovementsModel(this._repository);

  final MovementRepository _repository;

  bool _loading = false;
  String? _error;
  List<StockMovement> _movements = const [];

  bool get isLoading => _loading;
  String? get error => _error;
  List<StockMovement> get movements => List.unmodifiable(_movements);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    switch (await _repository.fetchAll()) {
      case Ok(:final value):
        _movements = value;
      case Err(:final msg):
        _error = msg;
    }
    _loading = false;
    notifyListeners();
  }

  List<StockMovement> forProduct(int productId) =>
      _movements.where((m) => m.productId == productId).toList();

  Future<String?> add(StockMovement draft) async {
    switch (await _repository.create(draft)) {
      case Ok(:final value):
        _movements = [value, ..._movements];
        notifyListeners();
        return null;
      case Err(:final msg):
        return msg;
    }
  }
}
