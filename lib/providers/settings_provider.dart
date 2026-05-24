import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class SettingsProvider extends ChangeNotifier {
  final DatabaseHelper _db;

  int _gridColumns = 2;
  String _defaultReaderMode = 'scroll';
  bool _rtlMode = false;
  String _readerBg = 'black';
  bool _autoScan = true;

  SettingsProvider(this._db);

  int get gridColumns => _gridColumns;
  String get defaultReaderMode => _defaultReaderMode;
  bool get rtlMode => _rtlMode;
  String get readerBg => _readerBg;
  bool get autoScan => _autoScan;

  /// Load settings from database.
  Future<void> loadSettings() async {
    final gc = await _db.getConfig('grid_columns');
    _gridColumns = int.tryParse(gc ?? '2') ?? 2;

    _defaultReaderMode = await _db.getConfig('default_reader_mode') ?? 'scroll';
    _rtlMode = (await _db.getConfig('rtl_mode')) == 'true';
    _readerBg = await _db.getConfig('reader_bg') ?? 'black';
    _autoScan = (await _db.getConfig('auto_scan') ?? 'true') == 'true';

    notifyListeners();
  }

  /// Set grid columns (2 or 3).
  Future<void> setGridColumns(int columns) async {
    _gridColumns = columns.clamp(2, 3);
    await _db.setConfig('grid_columns', _gridColumns.toString());
    notifyListeners();
  }

  /// Set default reader mode.
  Future<void> setDefaultReaderMode(String mode) async {
    _defaultReaderMode = mode;
    await _db.setConfig('default_reader_mode', mode);
    notifyListeners();
  }

  /// Set RTL mode.
  Future<void> setRtlMode(bool rtl) async {
    _rtlMode = rtl;
    await _db.setConfig('rtl_mode', rtl.toString());
    notifyListeners();
  }

  /// Set reader background color.
  Future<void> setReaderBg(String bg) async {
    _readerBg = bg;
    await _db.setConfig('reader_bg', bg);
    notifyListeners();
  }

  /// Set auto-scan on start.
  Future<void> setAutoScan(bool value) async {
    _autoScan = value;
    await _db.setConfig('auto_scan', value.toString());
    notifyListeners();
  }
}
