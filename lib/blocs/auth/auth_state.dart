import 'package:equatable/equatable.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, loading }

class AuthState extends Equatable {
  final AuthStatus status;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.email,
    this.displayName,
    this.photoUrl,
    this.error,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.loading() : this(status: AuthStatus.loading);

  const AuthState.authenticated({
    required String email,
    String? displayName,
    String? photoUrl,
  }) : this(
          status: AuthStatus.authenticated,
          email: email,
          displayName: displayName,
          photoUrl: photoUrl,
        );

  const AuthState.unauthenticated({String? error})
      : this(status: AuthStatus.unauthenticated, error: error);

  @override
  List<Object?> get props => [status, email, displayName, photoUrl, error];
}
