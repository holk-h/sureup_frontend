/// 稳了！API配置
class Environment {
  static const String appwriteProjectId = '6901942c30c3962e66eb';
  static const String appwriteProjectName = 'sureup';
  static const String appwritePublicEndpoint = 'https://api.delvetech.cn/v1';
}

/// API相关常量配置
class ApiConfig {
  // Appwrite配置
  static const String projectId = Environment.appwriteProjectId;
  static const String projectName = Environment.appwriteProjectName;
  static const String endpoint = Environment.appwritePublicEndpoint;
  
  // 数据库配置
  static const String databaseId = 'main';
  
  // 集合ID配置
  static const String usersCollectionId = 'profiles';  // 用户档案集合
  static const String subjectsCollectionId = 'subjects';
  static const String questionsCollectionId = 'questions';
  static const String practiceSessionsCollectionId = 'practice_sessions';
  static const String mistakeRecordsCollectionId = 'mistake_records';
  static const String weeklyReportsCollectionId = 'weekly_reports';
  static const String knowledgePointsCollectionId = 'user_knowledge_points';  // 用户知识点树
  
  // 存储桶配置
  static const String imagesBucketId = 'images';
  static const String documentsBucketId = 'documents';
  
  // API超时配置
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
  
  // 分页配置
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // 文件上传配置
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> allowedDocumentTypes = ['pdf', 'doc', 'docx'];
}
