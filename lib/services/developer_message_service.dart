import 'package:appwrite/appwrite.dart';
import '../config/api_config.dart';

/// 开发者消息数据模型
class DeveloperMessage {
  final String id;
  final String msg;
  final String? img;

  DeveloperMessage({
    required this.id,
    required this.msg,
    this.img,
  });

  factory DeveloperMessage.fromJson(Map<String, dynamic> json) {
    return DeveloperMessage(
      id: json['id'] ?? '',
      msg: json['msg'] ?? '',
      img: json['img'] as String?,
    );
  }
}

/// 开发者消息服务
class DeveloperMessageService {
  static final DeveloperMessageService _instance = DeveloperMessageService._internal();
  factory DeveloperMessageService() => _instance;
  DeveloperMessageService._internal();

  late Databases _databases;

  /// 初始化服务
  void initialize(Client client) {
    _databases = Databases(client);
  }

  /// 获取最新的开发者消息
  /// 返回最新的第一条消息，如果没有则返回 null
  Future<DeveloperMessage?> getLatestMessage() async {
    try {
      final response = await _databases.listDocuments(
        databaseId: ApiConfig.databaseId,
        collectionId: ApiConfig.devMsgCollectionId,
        queries: [
          Query.orderDesc('\$createdAt'),
          Query.limit(1),
        ],
      );

      if (response.documents.isEmpty) {
        return null;
      }

      final doc = response.documents.first;
      return DeveloperMessage.fromJson({
        'id': doc.$id,
        'msg': doc.data['msg'] ?? '',
        'img': doc.data['img'],
      });
    } catch (e) {
      print('获取开发者消息失败: $e');
      return null;
    }
  }
}

