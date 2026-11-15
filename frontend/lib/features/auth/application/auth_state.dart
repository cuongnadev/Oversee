import 'package:equatable/equatable.dart';

enum AuthStatus { authenticated, unauthenticated, initial }

class AuthState extends Equatable {
  final AuthStatus status;
  final String? accessToken;
  final String? email;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.accessToken,
    this.email,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.initial;

  AuthState copyWith({
    AuthStatus? status,
    String? accessToken,
    String? email,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      accessToken: accessToken ?? this.accessToken,
      email: email ?? this.email,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, accessToken, email, errorMessage];
}
