import 'dart:io';
import 'dart:typed_data';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:smb_connect/smb_connect.dart' as smb;
import 'package:path/path.dart' as p;
import '../models/remote_source.dart';

class RemoteFile {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final bool isDirectory;

  RemoteFile({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    this.isDirectory = false,
  });
}

class RemoteStorageService {
  /// List files in a remote directory recursively.
  Future<List<RemoteFile>> listFiles(RemoteSource source, {String? subPath}) async {
    if (source.type == RemoteSourceType.webdav) {
      return _listWebDav(source, subPath ?? source.rootPath);
    } else {
      return _listSmb(source, subPath ?? source.rootPath);
    }
  }

  Future<List<RemoteFile>> _listWebDav(RemoteSource source, String path) async {
    final client = webdav.newClient(
      source.url,
      user: source.username ?? '',
      password: source.password ?? '',
    );
    
    final List<RemoteFile> results = [];
    final queue = [path];

    while (queue.isNotEmpty) {
      final currentPath = queue.removeAt(0);
      try {
        final files = await client.readDir(currentPath);
        for (final f in files) {
          final name = f.name?.isNotEmpty == true ? f.name! : p.basename(f.path!);
          if (name == '.' || name == '..' || f.path == currentPath) continue;
          
          // webdav_client 1.2.2 properties: isDir, mTime, size
          if (f.isDir == true) {
            queue.add(f.path!);
          } else {
            results.add(RemoteFile(
              path: f.path!,
              name: name,
              size: f.size ?? 0,
              modified: f.mTime ?? DateTime.now(),
            ));
          }
        }
      } catch (e) {
        print('WebDAV list error: $e');
      }
    }
    return results;
  }

  Future<List<RemoteFile>> _listSmb(RemoteSource source, String path) async {
    final connect = await smb.SmbConnect.connectAuth(
      host: source.url,
      username: source.username ?? 'guest',
      password: source.password ?? '',
      domain: '',
    );

    final List<RemoteFile> results = [];
    final queue = [path];

    while (queue.isNotEmpty) {
      final currentPath = queue.removeAt(0);
      try {
        final folder = await connect.file(currentPath);
        final files = await connect.listFiles(folder);
        for (final f in files) {
          if (f.name == '.' || f.name == '..') continue;
          
          // smb_connect 0.0.9: isDirectory() returns bool, lastModified is int, size is num
          if (f.isDirectory()) {
            queue.add(f.path);
          } else {
            results.add(RemoteFile(
              path: f.path,
              name: f.name,
              size: f.size.toInt(),
              modified: DateTime.fromMillisecondsSinceEpoch(f.lastModified),
            ));
          }
        }
      } catch (e) {
        print('SMB list error: $e');
      }
    }
    return results;
  }

  /// Download a remote file to a local path.
  Future<File> downloadFile(RemoteSource source, String remotePath, String localPath) async {
    if (source.type == RemoteSourceType.webdav) {
       final client = webdav.newClient(
        source.url,
        user: source.username ?? '',
        password: source.password ?? '',
      );
      // read2File is the correct method for 1.2.2
      await client.read2File(remotePath, localPath);
    } else {
      final connect = await smb.SmbConnect.connectAuth(
        host: source.url,
        username: source.username ?? 'guest',
        password: source.password ?? '',
        domain: '',
      );
      final smbFile = await connect.file(remotePath);
      final stream = await connect.openRead(smbFile);
      final localFile = File(localPath);
      final sink = localFile.openWrite();
      await sink.addStream(stream);
      await sink.close();
    }
    return File(localPath);
  }

  /// Read a chunk of a remote file.
  Future<Uint8List> readRange(RemoteSource source, String remotePath, int offset, int length) async {
    throw UnimplementedError('Direct range read not supported in this version');
  }
}
