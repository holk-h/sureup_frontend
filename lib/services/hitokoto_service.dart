import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/hitokoto.dart';

/// 一言服务
class HitokotoService {
  static const String baseUrl = 'https://v1.hitokoto.cn';

  /// 获取一言
  /// 
  /// [categories] 句子类型，例如：['a', 'c', 'd'] 表示动画、游戏、文学
  /// [minLength] 最小长度
  /// [maxLength] 最大长度
  static Future<Hitokoto?> getHitokoto({
    List<String>? categories,
    int? minLength,
    int? maxLength,
  }) async {
    try {
      // 构建请求 URL
      final uri = Uri.parse(baseUrl).replace(
        queryParameters: {
          if (categories != null && categories.isNotEmpty)
            'c': categories,
          if (minLength != null) 'min_length': minLength.toString(),
          if (maxLength != null) 'max_length': maxLength.toString(),
        },
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return Hitokoto.fromJson(json);
      }
      return null;
    } catch (e) {
      // 网络错误或解析错误
      return null;
    }
  }
}

