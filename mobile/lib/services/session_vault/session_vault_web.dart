import 'dart:convert';
import 'dart:html' as html;
import 'session_vault.dart';

SessionVault getDefaultSessionVault() => WebSessionVault();

/// Web implementation of [SessionVault] utilizing browser [html.window.sessionStorage].
///
/// Unlike [html.window.localStorage] (which is shared across all browser tabs of an origin),
/// [html.window.sessionStorage] is strictly scoped per browser tab.
///
/// This provides two major advantages:
/// 1. Complete tab independence: you can test multiple roles/users (such as Anna Recycler
///    and Erik Helper) in separate tabs of the exact same browser without session overlap.
/// 2. Enhanced security: session tokens are not persisted permanently to disk, and are
///    automatically purged when the tab is closed, mitigating token retention risks.
class WebSessionVault implements SessionVault {
  WebSessionVault() {
    _cleanupLegacyLocalStorage();
  }

  void _cleanupLegacyLocalStorage() {
    try {
      // Clean up legacy tokens stored in localStorage from previous versions
      // that would otherwise bleed across browser tabs.
      html.window.localStorage.remove('flutter.panta_custom_jwt');
      html.window.localStorage.remove('panta_custom_jwt');
    } catch (_) {}
  }

  @override
  Future<void> setItem(String key, String value) async {
    try {
      html.window.sessionStorage[key] = value;
    } catch (_) {}
  }

  @override
  Future<String?> getItem(String key) async {
    try {
      return html.window.sessionStorage[key];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> removeItem(String key) async {
    try {
      html.window.sessionStorage.remove(key);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      html.window.sessionStorage.clear();
    } catch (_) {}
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    try {
      html.window.sessionStorage[key] = json.encode(value);
    } catch (_) {}
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    try {
      final raw = html.window.sessionStorage[key];
      if (raw == null) return null;
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
