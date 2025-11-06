import 'package:flutter/cupertino.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// 支持 Markdown 和 LaTeX 的文本渲染 widget
/// 使用 gpt_markdown 包，原生支持 Markdown 和 LaTeX
/// gpt_markdown 本身已支持文本选择，无需额外包装
class MathMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle style;
  /// 是否允许横向滚动（用于处理长公式溢出问题）
  final bool scrollable;

  const MathMarkdownText({
    super.key,
    required this.text,
    required this.style,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = GptMarkdown(
      text,
      style: style,
    );

    // 如果允许滚动，包装在 SingleChildScrollView 中
    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: child,
      );
    }

    return child;
  }
}
