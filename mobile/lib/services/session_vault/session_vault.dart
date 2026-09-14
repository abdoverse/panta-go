import 'package:flutter/foundation.dart';
import 'session_vault_stub.dart'
    if (dart.library.html) 'session_vault_web.dart';

export 'session_vault_stub.dart'
    if (dart.library.html) 'session_vault_web.dart';

/// Abstract storage interface for session authentication credentials and user profile tokens.
///
/// On Web platforms, this is backed by `window.sessionStorage` so each browser tab
/// operates in its own isolated session boundary. This allows concurrent testing
/// of different roles/users (e.g. Anna Recycler and Erik Helper) in separate tabs
/// of the same browser without session overlap, while automatically cleaning up
/// on tab close for security.
///
/// On Mobile and native platforms, this is backed by [SharedPreferences] to maintain
/// standard app lifecycle persistence.
abstract class SessionVault {
  static SessionVault? _overrideInstance;

  static SessionVault get instance =>
      _overrideInstance ?? getDefaultSessionVault();

  @visibleForTesting
  static set instance(SessionVault? vault) {
    _overrideInstance = vault;
  }

  Future<void> setItem(String key, String value);
  Future<String?> getItem(String key);
  Future<void> removeItem(String key);
  Future<void> clear();

  Future<void> setStringList(String key, List<String> value);
  Future<List<String>?> getStringList(String key);
}

/// In-memory implementation of [SessionVault] used for testing and isolated simulation.
class SessionMemoryVault implements SessionVault {
  final Map<String, String> _items = {};
  final Map<String, List<String>> _lists = {};

  @override
  Future<void> setItem(String key, String value) async {
    _items[key] = value;
  }

  @override
  Future<String?> getItem(String key) async {
    return _items[key];
  }

  @override
  Future<void> removeItem(String key) async {
    _items.remove(key);
  }

  @override
  Future<void> clear() async {
    _items.clear();
    _lists.clear();
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    _lists[key] = List.from(value);
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final list = _lists[key];
    return list != null ? List.from(list) : null;
  }
}
