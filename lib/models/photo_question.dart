/// 照片题目模型
/// 支持单图题和多图题
class PhotoQuestion {
  final List<String> photosPaths; // 照片路径列表
  final bool isMultiPhoto; // 是否是多图题

  PhotoQuestion({
    required this.photosPaths,
    this.isMultiPhoto = false,
  });

  // 是否为单图题
  bool get isSinglePhoto => photosPaths.length == 1;

  // 照片数量
  int get photoCount => photosPaths.length;

  // 创建单图题
  factory PhotoQuestion.single(String photoPath) {
    return PhotoQuestion(
      photosPaths: [photoPath],
      isMultiPhoto: false,
    );
  }

  // 创建多图题
  factory PhotoQuestion.multi(List<String> photosPaths) {
    return PhotoQuestion(
      photosPaths: photosPaths,
      isMultiPhoto: true,
    );
  }

  // 将所有题目展平为照片路径列表（用于上传）
  static List<String> flattenToPhotos(List<PhotoQuestion> questions) {
    final List<String> allPhotos = [];
    for (final question in questions) {
      allPhotos.addAll(question.photosPaths);
    }
    return allPhotos;
  }
}

