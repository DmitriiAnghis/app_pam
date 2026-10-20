import 'location.dart';
import 'result.dart';

abstract class LocationRepository {
  Future<Result<List<Location>>> fetchAll();
  Future<Result<Location>> fetchById(int id);
}
