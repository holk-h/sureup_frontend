import 'package:flutter/cupertino.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// 支持 Markdown 和 LaTeX 的文本渲染 widget
/// 使用 gpt_markdown 包，原生支持 Markdown 和 LaTeX
/// gpt_markdown 本身已支持文本选择，无需额外包装
class MathMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const MathMarkdownText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return GptMarkdown(
      text,
      style: style,
    );
  }
}
