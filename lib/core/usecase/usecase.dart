import 'package:equatable/equatable.dart';

/// An application action. Implementations throw only `Failure`s.
abstract interface class UseCase<Output, Params> {
  Future<Output> call(Params params);
}

final class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object> get props => [];
}
