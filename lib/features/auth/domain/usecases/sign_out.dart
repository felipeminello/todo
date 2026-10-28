import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/auth/domain/repositories/auth_repository.dart';

final class SignOut implements UseCase<void, NoParams> {
  const SignOut(this._repository);

  final AuthRepository _repository;

  @override
  Future<void> call([NoParams params = const NoParams()]) =>
      _repository.signOut();
}
