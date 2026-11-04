import 'package:app_pam/data/auth_api.dart';
import 'package:app_pam/data/result.dart';
import 'package:app_pam/data/token_store.dart';

class FakeAuthApi extends AuthApi {
  FakeAuthApi() : super('', TokenStore());

  @override
  Future<Result<void>> login(String email, String password) async =>
      password == 'parola123'
      ? const Ok(null)
      : const Err('Неверный email или пароль');
}
