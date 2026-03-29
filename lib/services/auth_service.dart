import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'log_service.dart';

/// 認證服務（Google Sign-In / Apple Sign-In + Firebase Auth）
class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  /// 目前使用者
  static User? get currentUser => _auth.currentUser;

  /// 是否已登入（非匿名）
  static bool get isSignedIn => currentUser != null && !currentUser!.isAnonymous;

  /// 是否有任何登入（含匿名）
  static bool get hasAnyAuth => currentUser != null;

  /// 顯示名稱
  static String? get displayName => currentUser?.displayName;

  /// Email
  static String? get email => currentUser?.email;

  /// Apple Sign-In
  static Future<User?> signInWithApple() async {
    LogService.info(LogTag.AUTH, 'Apple Sign-In started');
    // 產生 nonce 防止 replay attack
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    // 呼叫 Apple Sign-In
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    // 用 Apple 的 identityToken 建立 Firebase credential
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    // 如果目前是匿名登入，link 到 Apple 帳號（保留原有資料）
    UserCredential result;
    if (currentUser != null && currentUser!.isAnonymous) {
      try {
        LogService.debug(LogTag.AUTH, 'Linking anonymous account to Apple');
        result = await currentUser!.linkWithCredential(oauthCredential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          LogService.warning(LogTag.AUTH, 'Apple credential already in use, signing in directly');
          // 這個 Apple ID 已在別的裝置登入過 → 直接登入那個帳號
          result = await _auth.signInWithCredential(oauthCredential);
        } else {
          LogService.error(LogTag.AUTH, 'Apple Sign-In link failed', e);
          rethrow;
        }
      }
    } else {
      result = await _auth.signInWithCredential(oauthCredential);
    }

    // 儲存 Apple 提供的姓名（Apple 只在第一次授權時給 name）
    final user = result.user;
    if (user != null && user.displayName == null) {
      final fullName = [
        appleCredential.familyName,
        appleCredential.givenName,
      ].where((n) => n != null && n.isNotEmpty).join('');
      if (fullName.isNotEmpty) {
        await user.updateDisplayName(fullName);
      }
    }

    LogService.info(LogTag.AUTH, 'Apple Sign-In success: ${user?.email ?? user?.uid}');
    return user;
  }

  /// Google Sign-In（含 serverClientId 給 iOS/macOS 使用）
  static Future<User?> signInWithGoogle() async {
    LogService.info(LogTag.AUTH, 'Google Sign-In started');
    final googleSignIn = GoogleSignIn(
      scopes: ['email'],
      serverClientId: '137558877215-85ak3t2lbne5iuad4aoop4fadn2m4p7u.apps.googleusercontent.com',
    );

    // Step 1: 開啟 Google 登入畫面
    LogService.debug(LogTag.AUTH, 'Step 1: Opening Google Sign-In popup');
    final GoogleSignInAccount? googleUser;
    try {
      googleUser = await googleSignIn.signIn();
    } catch (e, st) {
      LogService.error(LogTag.AUTH, 'Step 1 FAILED: Google Sign-In popup error (${e.runtimeType})', e, st);
      rethrow;
    }
    if (googleUser == null) {
      LogService.info(LogTag.AUTH, 'Step 1: Google Sign-In cancelled by user');
      return null;
    }
    LogService.info(LogTag.AUTH, 'Step 1 OK: Google user = ${googleUser.email}');

    // Step 2: 取得 Google 認證 token
    LogService.debug(LogTag.AUTH, 'Step 2: Getting Google auth tokens');
    final GoogleSignInAuthentication googleAuth;
    try {
      googleAuth = await googleUser.authentication;
    } catch (e, st) {
      LogService.error(LogTag.AUTH, 'Step 2 FAILED: Google auth token error (${e.runtimeType})', e, st);
      rethrow;
    }
    LogService.info(LogTag.AUTH, 'Step 2 OK: accessToken=${googleAuth.accessToken != null ? "present" : "NULL"}, idToken=${googleAuth.idToken != null ? "present" : "NULL"}');

    // Step 3: 建立 Firebase credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    LogService.debug(LogTag.AUTH, 'Step 3: Firebase credential created');

    // Step 4: Firebase signInWithCredential
    LogService.debug(LogTag.AUTH, 'Step 4: Calling Firebase signInWithCredential');
    UserCredential result;
    if (currentUser != null && currentUser!.isAnonymous) {
      try {
        LogService.debug(LogTag.AUTH, 'Step 4: Linking anonymous account to Google');
        result = await currentUser!.linkWithCredential(credential);
      } on FirebaseAuthException catch (e, st) {
        if (e.code == 'credential-already-in-use') {
          LogService.warning(LogTag.AUTH, 'Google credential already in use, signing in directly');
          result = await _auth.signInWithCredential(credential);
        } else {
          LogService.error(LogTag.AUTH, 'Step 4 FAILED: Firebase link error [${e.code}]', e, st);
          rethrow;
        }
      }
    } else {
      try {
        result = await _auth.signInWithCredential(credential);
      } catch (e, st) {
        LogService.error(LogTag.AUTH, 'Step 4 FAILED: Firebase signIn error (${e.runtimeType})', e, st);
        rethrow;
      }
    }

    LogService.info(LogTag.AUTH, 'Step 4 OK: Firebase sign-in success: ${result.user?.email ?? result.user?.uid}');
    return result.user;
  }

  /// 匿名登入（fallback）
  static Future<User?> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    return credential.user;
  }

  /// 登出
  static Future<void> signOut() async {
    LogService.info(LogTag.AUTH, 'Signing out: ${currentUser?.email ?? currentUser?.uid}');
    await _auth.signOut();
    LogService.info(LogTag.AUTH, 'Signed out');
  }

  /// 監聽登入狀態變更
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── 工具方法 ──

  static String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
