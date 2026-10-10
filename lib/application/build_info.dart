// Сведения о сборке и флаг дев-инструментов (D-018).

/// Дев-инструменты (чит-меню, «Сброс прогресса (dev)») в любой сборке.
///
/// D-018: пока игра в тесте, флаг включён по умолчанию — читы доступны и в
/// release, поставленном с иконки. Выключается `--dart-define=DEV_TOOLS=false`.
/// ДО ПУБЛИКАЦИИ в сторы флаг выключить (или сменить значение по умолчанию).
const bool kDevTools = bool.fromEnvironment('DEV_TOOLS', defaultValue: true);

/// Короткий хеш коммита сборки (`--dart-define=BUILD_COMMIT=<hash>`); пусто,
/// если не передан.
const String kBuildCommit = String.fromEnvironment('BUILD_COMMIT');

/// Время сборки (`--dart-define=BUILD_TIME=<время>`); пусто, если не передано.
const String kBuildTime = String.fromEnvironment('BUILD_TIME');

/// Подпись сборки: «`<commit> · <time>`»; пустые части опускаются, обе пустые —
/// «dev».
String buildLabel() => composeBuildLabel(kBuildCommit, kBuildTime);

/// Сборка подписи из частей — отдельной функцией, чтобы тестировать без
/// `--dart-define`.
String composeBuildLabel(String commit, String time) {
  final parts = [if (commit.isNotEmpty) commit, if (time.isNotEmpty) time];
  return parts.isEmpty ? 'dev' : parts.join(' · ');
}
