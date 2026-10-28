import 'package:todo/core/usecase/usecase.dart';
import 'package:todo/features/auth/domain/entities/app_user.dart';
import 'package:todo/features/auth/domain/repositories/auth_repository.dart';

final class RestoreSession implements UseCase<AppUser?, NoParams> {
  const RestoreSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<AppUser?> call([NoParams params = const NoParams()]) =>
      _repository.restoreSession();
}
