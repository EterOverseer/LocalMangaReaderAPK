import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/tag.dart';

class ConfigManager {
  final DatabaseHelper _db;

  ConfigManager(this._db);

  /// Export configuration to JSON string.
  Future<String> exportConfig() async {
    final db = await _db.database;

    // Get source folders
    final sourcesRaw = await _db.getConfig('source_folders');
    final sources = sourcesRaw != null
        ? (jsonDecode(sourcesRaw) as List).cast<String>()
        : <String>[];

    // Get all tags
    final tagMaps = await db.query('tags', orderBy: 'name ASC');
    final tags = tagMaps.map((m) => Tag.fromMap(m)).toList();

    // Get settings
    final gridColumns = await _db.getConfig('grid_columns') ?? '2';
    final defaultReaderMode =
        await _db.getConfig('default_reader_mode') ?? 'scroll';
    final rtlMode = await _db.getConfig('rtl_mode') ?? 'false';
    final readerBg = await _db.getConfig('reader_bg') ?? 'black';

    final config = {
      'version': 1,
      'exported_at': DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now()),
      'sources': sources,
      'tags': tags.map((t) => t.toJson()).toList(),
      'settings': {
        'grid_columns': int.tryParse(gridColumns) ?? 2,
        'default_reader_mode': defaultReaderMode,
        'rtl_mode': rtlMode == 'true',
        'reader_bg': readerBg,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(config);
  }

  /// Export configuration to a file.
  Future<File> exportToFile(String outputPath) async {
    final json = await exportConfig();
    final file = File(outputPath);
    return await file.writeAsString(json);
  }

  /// Import configuration from JSON string.
  Future<void> importConfig(String jsonString) async {
    final db = await _db.database;
    final config = jsonDecode(jsonString) as Map<String, dynamic>;

    final version = config['version'] as int? ?? 1;
    if (version != 1) {
      throw FormatException('Unsupported config version: $version');
    }

    // Import sources
    final sources = (config['sources'] as List?)?.cast<String>() ?? [];
    await _db.setConfig('source_folders', jsonEncode(sources));

    // Import tags
    final tagsJson = (config['tags'] as List?) ?? [];
    for (final tagJson in tagsJson) {
      final tag = Tag.fromJson(tagJson as Map<String, dynamic>);
      // Insert or update
      await db.insert(
        'tags',
        tag.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      // Update color and label if tag already exists
      await db.update(
        'tags',
        {'color': tag.color, 'label': tag.label},
        where: 'name = ?',
        whereArgs: [tag.name],
      );
    }

    // Import settings
    final settings = config['settings'] as Map<String, dynamic>? ?? {};
    if (settings.containsKey('grid_columns')) {
      await _db.setConfig('grid_columns', settings['grid_columns'].toString());
    }
    if (settings.containsKey('default_reader_mode')) {
      await _db.setConfig(
          'default_reader_mode', settings['default_reader_mode'] as String);
    }
    if (settings.containsKey('rtl_mode')) {
      await _db.setConfig('rtl_mode', settings['rtl_mode'].toString());
    }
    if (settings.containsKey('reader_bg')) {
      await _db.setConfig('reader_bg', settings['reader_bg'] as String);
    }
  }

  /// Import configuration from a file.
  Future<void> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Config file not found', filePath);
    }
    final json = await file.readAsString();
    await importConfig(json);
  }
}
