import 'package:flutter/foundation.dart';

/// ログレベル
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// アプリケーション全体で使用するロガー
/// 
/// デバッグビルドでのみログを出力し、リリースビルドでは出力しない
class AppLogger {
  /// 現在のログレベル（これ以上のレベルのみ出力）
  static LogLevel currentLevel = LogLevel.debug;

  /// ログを出力（kDebugModeの場合のみ）
  static void log(String message, {LogLevel level = LogLevel.debug}) {
    if (!kDebugMode) return;
    if (level.index < currentLevel.index) return;

    final prefix = _getPrefix(level);
    debugPrint('$prefix$message');
  }

  /// デバッグログ
  static void debug(String message) {
    log(message, level: LogLevel.debug);
  }

  /// 情報ログ
  static void info(String message) {
    log(message, level: LogLevel.info);
  }

  /// 警告ログ
  static void warning(String message) {
    log(message, level: LogLevel.warning);
  }

  /// エラーログ
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    log(message, level: LogLevel.error);
    if (error != null && kDebugMode) {
      debugPrint('Error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint('StackTrace: $stackTrace');
    }
  }

  /// セクション開始のログ
  static void section(String title) {
    if (!kDebugMode) return;
    debugPrint('=== $title ===');
  }

  /// セクション終了のログ
  static void sectionEnd() {
    if (!kDebugMode) return;
    debugPrint('=====================================');
  }

  /// サブセクション開始のログ
  static void subSection(String title) {
    if (!kDebugMode) return;
    debugPrint('--- $title ---');
  }

  static String _getPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '';
      case LogLevel.info:
        return '[INFO] ';
      case LogLevel.warning:
        return '[WARN] ';
      case LogLevel.error:
        return '[ERROR] ';
    }
  }
}

