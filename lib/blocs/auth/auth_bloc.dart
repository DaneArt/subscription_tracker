import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(const AuthState.unknown()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());
    try {
      await _authService.init();
      if (_authService.isSignedIn) {
        emit(AuthState.authenticated(
          email: _authService.userEmail!,
          displayName: _authService.userName,
          photoUrl: _authService.userPhotoUrl,
        ));
      } else {
        emit(const AuthState.unauthenticated());
      }
    } catch (e) {
      emit(AuthState.unauthenticated(error: e.toString()));
    }
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());
    try {
      final user = await _authService.signIn();
      if (user != null) {
        emit(AuthState.authenticated(
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoUrl,
        ));
      } else {
        emit(const AuthState.unauthenticated(error: 'Sign in cancelled'));
      }
    } catch (e) {
      emit(AuthState.unauthenticated(error: e.toString()));
    }
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authService.signOut();
    emit(const AuthState.unauthenticated());
  }

  AuthService get authService => _authService;
}
