import 'package:appwrite/appwrite.dart';
import '../config/api_config.dart';

/// Appwrite 服务 - 用于统一管理 Appwrite 客户端和 SDK 服务
class AppwriteService {
  late final Client _client;
  late final Account _account;
  late final Databases _databases;
  late final Functions _functions;

  // Singleton
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;

  AppwriteService._internal() {
    _client = Client()
        .setEndpoint(ApiConfig.endpoint)
        .setProject(ApiConfig.projectId);

    _account = Account(_client);
    _databases = Databases(_client);
    _functions = Functions(_client);
  }

  Client get client => _client;
  Account get account => _account;
  Databases get databases => _databases;
  Functions get functions => _functions;
}
