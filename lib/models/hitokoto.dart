/// 一言数据模型
class Hitokoto {
  final int id;
  final String hitokoto; // 一言正文
  final String type; // 类型
  final String from; // 出处
  final String? fromWho; // 作者
  final String creator; // 添加者
  final int creatorUid; // 添加者用户标识
  final String uuid; // 一言唯一标识
  final int length; // 句子长度

  Hitokoto({
    required this.id,
    required this.hitokoto,
    required this.type,
    required this.from,
    this.fromWho,
    required this.creator,
    required this.creatorUid,
    required this.uuid,
    required this.length,
  });

  factory Hitokoto.fromJson(Map<String, dynamic> json) {
    return Hitokoto(
      id: json['id'] as int,
      hitokoto: json['hitokoto'] as String,
      type: json['type'] as String,
      from: json['from'] as String,
      fromWho: json['from_who'] as String?,
      creator: json['creator'] as String,
      creatorUid: json['creator_uid'] as int,
      uuid: json['uuid'] as String,
      length: json['length'] as int,
    );
  }

  /// 获取类型的中文名称
  String getTypeName() {
    switch (type) {
      case 'a': return '动画';
      case 'b': return '漫画';
      case 'c': return '游戏';
      case 'd': return '文学';
      case 'e': return '原创';
      case 'f': return '网络';
      case 'g': return '其他';
      case 'h': return '影视';
      case 'i': return '诗词';
      case 'k': return '哲学';
      case 'l': return '抖机灵';
      default: return '未知';
    }
  }
}

