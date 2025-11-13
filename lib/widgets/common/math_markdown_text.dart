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
  /// 最大行数
  final int? maxLines;
  /// 溢出处理方式
  final TextOverflow? overflow;

  const MathMarkdownText({
    super.key,
    required this.text,
    required this.style,
    this.scrollable = false,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = GptMarkdown(
      text,
      style: style,
    );

    // 如果设置了 maxLines，需要限制高度并裁剪
    if (maxLines != null) {
      final lineHeight = style.height ?? 1.0;
      final fontSize = style.fontSize ?? 10.0;
      // 计算单行的最大高度：字体大小 × 行高 × 行数
      final maxHeight = 0.9 * fontSize * lineHeight * maxLines!;
      
      // 使用 ConstrainedBox 限制最大高度，ClipRect 裁剪超出部分
      // 由于 GptMarkdown 可能不会自动换行，这里主要限制高度方向
      // 宽度方向的溢出由父级 Expanded 约束处理
      child = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
        ),
        child: ClipRect(
          child: child,
        ),
      );
    }

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
