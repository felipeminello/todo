import 'package:todo/features/auth/domain/repositories/auth_repository.dart';
import 'package:todo/features/auth/domain/repositories/current_user_id_provider.dart';

final class AuthCurrentUserIdProvider implements CurrentUserIdProvider {
  const AuthCurrentUserIdProvider(this._repository);

  final AuthRepository _repository;

  @override
  String? get currentUserId => _repository.currentUser?.id;
}
