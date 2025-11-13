import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../services/developer_message_service.dart';
import '../../services/appwrite_service.dart';
import 'math_markdown_text.dart';

/// 开发者的话弹窗 - 自定义卡片样式
class DeveloperMessageDialog extends StatefulWidget {
  const DeveloperMessageDialog({super.key});

  /// 显示开发者的话弹窗
  static Future<void> show(BuildContext context) {
    return showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => const DeveloperMessageDialog(),
    );
  }

  @override
  State<DeveloperMessageDialog> createState() => _DeveloperMessageDialogState();
}

class _DeveloperMessageDialogState extends State<DeveloperMessageDialog> {
  final _developerMessageService = DeveloperMessageService();
  DeveloperMessage? _message;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessage();
  }

  Future<void> _loadMessage() async {
    try {
      // 初始化服务
      _developerMessageService.initialize(AppwriteService().client);
      
      // 加载消息
      final message = await _developerMessageService.getLatestMessage();
      
      if (mounted) {
        setState(() {
          _message = message;
          _isLoading = false;
          if (message == null) {
            _error = '暂无开发者消息';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.85; // 屏幕宽度的85%
    
    return Center(
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(
          maxHeight: 600,
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.divider.withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      CupertinoIcons.chat_bubble_text_fill,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '开发者的话',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    minimumSize: const Size(0, 0),
                  ),
                ],
              ),
            ),
            
            // 内容区域
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CupertinoActivityIndicator(),
                      ),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : _message == null
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text('暂无消息'),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 文本内容
                                  DefaultTextStyle(
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                      height: 1.6,
                                    ),
                                    textAlign: TextAlign.left,
                                    child: MathMarkdownText(
                                      text: _message!.msg,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: AppColors.textPrimary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  
                                  // 图片（如果有）
                                  if (_message!.img != null && _message!.img!.isNotEmpty) ...[
                                    const SizedBox(height: 24),
                                    Center(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 200,
                                            maxHeight: 200,
                                          ),
                                          child: Image.network(
                                            _message!.img!,
                                            fit: BoxFit.contain,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Container(
                                                width: 150,
                                                height: 150,
                                                decoration: BoxDecoration(
                                                  color: AppColors.background,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Center(
                                                  child: CupertinoActivityIndicator(),
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                width: 150,
                                                height: 75,
                                                decoration: BoxDecoration(
                                                  color: AppColors.background,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '图片加载失败',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
