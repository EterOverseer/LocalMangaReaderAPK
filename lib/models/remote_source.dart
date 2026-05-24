enum RemoteSourceType { smb, webdav }

class RemoteSource {
  final int? id;
  final RemoteSourceType type;
  final String name;
  final String url;
  final String? username;
  final String? password;
  final String rootPath;

  RemoteSource({
    this.id,
    required this.type,
    required this.name,
    required this.url,
    this.username,
    this.password,
    this.rootPath = '/',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'url': url,
      'username': username,
      'password': password,
      'root_path': rootPath,
    };
  }

  factory RemoteSource.fromMap(Map<String, dynamic> map) {
    return RemoteSource(
      id: map['id'] as int?,
      type: RemoteSourceType.values.firstWhere((e) => e.name == map['type']),
      name: map['name'] as String,
      url: map['url'] as String,
      username: map['username'] as String?,
      password: map['password'] as String?,
      rootPath: map['root_path'] as String,
    );
  }
}
