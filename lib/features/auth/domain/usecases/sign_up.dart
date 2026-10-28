import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/auth/domain/entities/app_user.dart';
import 'package:todo/features/auth/domain/entities/credentials.dart';
import 'package:todo/features/auth/domain/repositories/auth_repository.dart';

final class SignUp implements UseCase<AppUser, Credentials> {
  const SignUp(this._repository);

  final AuthRepository _repository;

  @override
  Future<AppUser> call(Credentials credentials) async {
    final valid = credentials.validated();
    return _repository.signUp(email: valid.email, password: valid.password);
  }
}
