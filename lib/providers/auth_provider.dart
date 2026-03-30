// Auth State Provider - 家庭記帳 App
//
// 將靜態 AuthService 改為 Riverpod StreamProvider
// 支援 ref.watch(authStateProvider) 全域取用認證狀態

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../exceptions/app_exception.dart';

/// Auth 狀態
enum AuthStatus {
  initial,   // 初始狀態（載入中）
  signedIn,   // 已登入（非匿名）
  anonymous,  // 匿名模式
  signedOut,  // 未登入
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  bool get isSignedIn => status == AuthStatus.signedIn;
  bool get isAnonymous => status == AuthStatus.anonymous;
  bool get hasAuth => user != null;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

/// Firebase Auth instance provider
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Google Sign-In instance provider
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    serverClientId: '137558877215-85ak3t2lbne5iuad4aoop4fadn2m4p7u.apps.googleusercontent.com',
  );
});

/// Auth State Stream Provider
/// 取代靜態 AuthService.authStateChanges，全域可 ref.watch
final authStateProvider = StreamProvider<AuthState>((ref) async* {
  final auth = ref.watch(firebaseAuthProvider);

  // 初始發射當前狀態
  final currentUser = auth.currentUser;
  if (currentUser != null) {
    yield AuthState(
      status: currentUser.isAnonymous
          ? AuthStatus.anonymous
          : AuthStatus.signedIn,
      user: currentUser,
    );
  } else {
    yield const AuthState(status: AuthStatus.signedOut);
  }

  // 監聽未來變化
  await for (final user in auth.authStateChanges()) {
    if (user == null) {
      yield const AuthState(status: AuthStatus.signedOut);
    } else if (user.isAnonymous) {
      yield AuthState(status: AuthStatus.anonymous, user: user);
    } else {
      yield AuthState(status: AuthStatus.signedIn, user: user);
    }
  }
});

/// 同步取得當前 Auth 狀態（一次性查詢）
final currentAuthProvider = FutureProvider<AuthState>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final user = auth.currentUser;
  if (user == null) {
    return const AuthState(status: AuthStatus.signedOut);
  }
  return AuthState(
    status: user.isAnonymous ? AuthStatus.anonymous : AuthStatus.signedIn,
    user: user,
  );
});

/// Auth Operations Notifier（處理登入/登出操作）
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthNotifier(this._auth, this._googleSignIn) : super(const AuthState()) {
    _auth.authStateChanges().listen((user) {
      if (user == null) {
        state = const AuthState(status: AuthStatus.signedOut);
      } else if (user.isAnonymous) {
        state = AuthState(status: AuthStatus.anonymous, user: user);
      } else {
        state = AuthState(status: AuthStatus.signedIn, user: user);
      }
    });
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.initial, errorMessage: null);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = const AuthState(status: AuthStatus.signedOut);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      state = AuthState(
        status: AuthStatus.signedIn,
        user: userCredential.user,
      );
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        status: AuthStatus.signedOut,
        errorMessage: e.message,
      );
      throw AuthException(
        e.message ?? 'Google 登入失敗',
        AuthErrorType.googleSignInFailed,
        stackTrace: e.stackTrace?.toString(),
      );
    } catch (e, st) {
      state = AuthState(
        status: AuthStatus.signedOut,
        errorMessage: e.toString(),
      );
      throw AuthException(
        e.toString(),
        AuthErrorType.googleSignInFailed,
        stackTrace: st.toString(),
      );
    }
  }

  Future<void> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      state = AuthState(
        status: AuthStatus.anonymous,
        user: userCredential.user,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        e.message ?? '匿名登入失敗',
        AuthErrorType.anonymousSignInFailed,
        stackTrace: e.stackTrace?.toString(),
      );
    }
  }

  Future<void> linkWithGoogleCredential(AuthCredential credential) async {
    try {
      final userCredential = await _auth.currentUser?.linkWithCredential(credential);
      if (userCredential != null) {
        state = AuthState(
          status: AuthStatus.signedIn,
          user: userCredential.user,
        );
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        e.message ?? '連結帳戶失敗',
        AuthErrorType.linkCredentialFailed,
        stackTrace: e.stackTrace?.toString(),
      );
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

/// Auth Notifier Provider
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final googleSignIn = ref.watch(googleSignInProvider);
  return AuthNotifier(auth, googleSignIn);
});
