import 'app_user.dart';
import 'result.dart';

abstract class UserRepository {
  Future<Result<AppUser>> fetchMe();
}
