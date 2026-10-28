import 'package:equatable/equatable.dart';
import 'package:todo/features/auth/domain/entities/app_user.dart';

final class UserModel extends Equatable {
  const UserModel({required this.id, required this.email});

  final String id;
  final String email;

  AppUser toEntity() => AppUser(id: id, email: email);

  @override
  List<Object> get props => [id, email];
}
