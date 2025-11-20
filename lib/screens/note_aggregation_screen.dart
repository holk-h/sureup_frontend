import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/colors.dart';
import '../models/mistake_record.dart';
import '../models/question.dart';
import '../providers/auth_provider.dart';
import '../services/mistake_service.dart';
import '../widgets/common/math_markdown_text.dart';

class NoteAggregationScreen extends StatefulWidget {
  const NoteAggregationScreen({super.key});

  @override
  State<NoteAggregationScreen> createState() => _NoteAggregationScreenState();
}

class _NoteAggregationScreenState extends State<NoteAggregationScreen> {
  bool _isLoading = true;
  List<MistakeRecord> _mistakes = [];
  Map<String, Question> _questions = {}; // 缓存题目数据

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final userId = context.read<AuthProvider>().userProfile?.id;
    if (userId == null) return;

    try {
      final mistakes = await MistakeService().getMistakesWithNotes(userId);
      
      // 加载关联的题目数据
      final questionIds = mistakes
          .where((m) => m.questionId != null)
          .map((m) => m.questionId!)
          .toSet()
          .toList();
      
      if (questionIds.isNotEmpty) {
        final questions = await MistakeService().getQuestions(questionIds);
        _questions = {for (var q in questions) q.id: q};
      }
      
      setState(() {
        _mistakes = mistakes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading notes: $e');
    }
  }

  /// 将文本渲染为图片（支持 Markdown 和 LaTeX）
  /// 返回：{'bytes': Uint8List, 'width': double, 'height': double}
  Future<Map<String, dynamic>?> _renderTextToImage(String text, {double maxWidth = 2000, double fontSize = 20}) async {
    try {
      final key = GlobalKey();
      
      final widget = RepaintBoundary(
        key: key,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.all(8), // 增加 padding 防止边缘被切
          color: Colors.white,
          child: MathMarkdownText(
            text: text,
            style: TextStyle(
              fontSize: fontSize,
              height: 1.2,
              color: Colors.black,
            ),
          ),
        ),
      );

      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -10000,
          top: -10000,
          child: Material(
            color: Colors.transparent,
            child: widget,
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry);
      await Future.delayed(const Duration(milliseconds: 100));

      final renderObject = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (renderObject == null) {
        overlayEntry.remove();
        return null;
      }

      // 获取逻辑尺寸
      final size = renderObject.size;

      // 转换为高清图片 (3.0x)
      final image = await renderObject.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      overlayEntry.remove();

      if (byteData == null) return null;

      return {
        'bytes': byteData.buffer.asUint8List(),
        'width': size.width,
        'height': size.height,
      };
    } catch (e) {
      debugPrint('渲染文本为图片失败: $e');
      return null;
    }
  }

  Future<void> _exportPdf() async {
    // 显示加载提示
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(),
            SizedBox(height: 16),
            Text('正在生成 PDF，请稍候...'),
          ],
        ),
      ),
    );

    try {
      final doc = pw.Document();
      
      // 加载中文字体
      final fontBold = await PdfGoogleFonts.notoSansSCBold();
      final fontRegular = await PdfGoogleFonts.notoSansSCRegular();

      // 为每个错题预渲染文本为图片
      final renderedContents = <int, Map<String, dynamic>>{};
      
      // 目标字号 6.5 (原 5.0 * 1.25)，渲染字号 20.0
      const double targetFontSize = 6.5;
      const double renderFontSize = 20.0;
      const double scaleFactor = targetFontSize / renderFontSize;
      
      // PDF 内容宽度约 480pt
      // 双栏布局：(480 - 间距10) / 2 = 235
      const double pdfContentWidth = 480.0;
      const double columnSpacing = 10.0;
      const double columnWidth = (pdfContentWidth - columnSpacing) / 2;
      
      // 渲染最大宽度需根据缩放比例放大
      const double renderMaxWidth = columnWidth / scaleFactor; 
      
      for (var i = 0; i < _mistakes.length; i++) {
        final mistake = _mistakes[i];
        final question = mistake.questionId != null ? _questions[mistake.questionId] : null;
        
        // 渲染题目内容
        Map<String, dynamic>? contentImage;
        if (question?.content != null) {
          contentImage = await _renderTextToImage(
            question!.content, 
            fontSize: renderFontSize,
            maxWidth: renderMaxWidth,
          );
        }

        // 获取题目配图
        List<Uint8List> extractedImages = [];
        if (question?.extractedImages != null && question!.extractedImages!.isNotEmpty) {
           try {
             final imagesMap = await MistakeService().getExtractedImages(question.extractedImages!);
             // 保持顺序
             for (var id in question.extractedImages!) {
               if (imagesMap.containsKey(id)) {
                 extractedImages.add(imagesMap[id]!);
               }
             }
           } catch (e) {
             debugPrint('Failed to load extracted images: $e');
           }
        }
        
        // 渲染选项
        Map<String, dynamic>? optionsImage;
        if (question?.options != null && question!.options!.isNotEmpty) {
          final optionsText = question.options!.join('\n');
          optionsImage = await _renderTextToImage(
            optionsText, 
            fontSize: renderFontSize,
            maxWidth: renderMaxWidth,
          );
        }
        
        // 渲染答案
        Map<String, dynamic>? answerImage;
        if (question?.answer != null && question!.answer!.isNotEmpty) {
          answerImage = await _renderTextToImage(
            question.answer!, 
            fontSize: renderFontSize,
            maxWidth: renderMaxWidth,
          );
        }
        
        // 渲染笔记
        Map<String, dynamic>? noteImage;
        if (mistake.note != null) {
          noteImage = await _renderTextToImage(
            mistake.note!, 
            fontSize: renderFontSize,
            maxWidth: renderMaxWidth,
          );
        }
        
        renderedContents[i] = {
          'content': contentImage,
          'extractedImages': extractedImages,
          'options': optionsImage,
          'answer': answerImage,
          'note': noteImage,
        };
      }

      // 构建双栏列表
      final List<pw.Widget> mistakeWidgets = [];
      for (var i = 0; i < _mistakes.length; i += 2) {
        final item1 = _buildMistakeItem(i, _mistakes[i], renderedContents[i]!, fontBold, fontRegular, scaleFactor);
        final item2 = (i + 1 < _mistakes.length) 
            ? _buildMistakeItem(i + 1, _mistakes[i + 1], renderedContents[i + 1]!, fontBold, fontRegular, scaleFactor)
            : null;

        mistakeWidgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: item1),
                pw.SizedBox(width: columnSpacing),
                pw.Expanded(child: item2 ?? pw.Container()), // 占位符保持对齐
              ],
            ),
          ),
        );
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(
            base: fontRegular,
            bold: fontBold,
          ),
          build: (pw.Context context) {
            return [
              pw.Center(
                child: pw.Text(
                  '错题笔记汇总',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    font: fontBold,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              ...mistakeWidgets,
            ];
          },
        ),
      );

      // 关闭加载对话框
      if (mounted) {
        Navigator.of(context).pop();
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: '错题笔记汇总.pdf',
      );
    } catch (e) {
      // 关闭加载对话框
      if (mounted) {
        Navigator.of(context).pop();
        
        // 显示错误提示
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('导出失败'),
            content: Text('生成 PDF 时出错：${e.toString()}'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
      debugPrint('导出 PDF 失败: $e');
    }
  }

  /// 构建单个错题项
  pw.Widget _buildMistakeItem(
    int index,
    MistakeRecord mistake,
    Map<String, dynamic> rendered,
    pw.Font fontBold,
    pw.Font fontRegular,
    double scaleFactor,
  ) {
    final question = mistake.questionId != null ? _questions[mistake.questionId] : null;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // 标题行：序号、学科、日期
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    '${index + 1}. ',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                    ),
                    child: pw.Text(
                      mistake.subject?.displayName ?? '未知学科',
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        font: fontRegular,
                      ),
                    ),
                  ),
                ],
              ),
              pw.Text(
                mistake.createdAt.toString().split(' ')[0],
                style: pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey600,
                  font: fontRegular,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          
          // 题目内容
          if (question != null) ...[
            pw.Text(
              '题目',
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
                font: fontBold,
              ),
            ),
            pw.SizedBox(height: 2),
            if (rendered['content'] != null)
              pw.Image(
                pw.MemoryImage((rendered['content'] as Map<String, dynamic>)['bytes'] as Uint8List),
                width: ((rendered['content'] as Map<String, dynamic>)['width'] as double) * scaleFactor,
              )
            else
              pw.Text(
                question.content,
                style: pw.TextStyle(fontSize: 6, height: 1.2, font: fontRegular),
              ),
            
            // 题目配图
            if (rendered['extractedImages'] != null && (rendered['extractedImages'] as List).isNotEmpty) ...[
              pw.SizedBox(height: 4),
              for (final imageBytes in (rendered['extractedImages'] as List<Uint8List>))
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Image(
                    pw.MemoryImage(imageBytes),
                    width: 60, // 限制图片宽度，避免过大
                    fit: pw.BoxFit.contain,
                  ),
                ),
            ],

            pw.SizedBox(height: 4),
            
            // 选项
            if (question.options != null && question.options!.isNotEmpty) ...[
              pw.Text(
                '选项',
                style: pw.TextStyle(
                  fontSize: 6.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                  font: fontBold,
                ),
              ),
              pw.SizedBox(height: 2),
              if (rendered['options'] != null)
                pw.Image(
                  pw.MemoryImage((rendered['options'] as Map<String, dynamic>)['bytes'] as Uint8List),
                  width: ((rendered['options'] as Map<String, dynamic>)['width'] as double) * scaleFactor,
                )
              else
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: question.options!.map((option) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 1.5),
                      child: pw.Text(
                        option,
                        style: pw.TextStyle(fontSize: 6, height: 1.2, font: fontRegular),
                      ),
                    );
                  }).toList(),
                ),
              pw.SizedBox(height: 4),
            ],
            
            // 答案
            if (question.answer != null && question.answer!.isNotEmpty) ...[
              pw.Text(
                '答案',
                style: pw.TextStyle(
                  fontSize: 6.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                  font: fontBold,
                ),
              ),
              pw.SizedBox(height: 2),
              if (rendered['answer'] != null)
                pw.Image(
                  pw.MemoryImage((rendered['answer'] as Map<String, dynamic>)['bytes'] as Uint8List),
                  width: ((rendered['answer'] as Map<String, dynamic>)['width'] as double) * scaleFactor,
                )
              else
                pw.Text(
                  question.answer!,
                  style: pw.TextStyle(fontSize: 6, height: 1.2, font: fontRegular),
                ),
              pw.SizedBox(height: 4),
            ],
          ],
          
          // 笔记
          pw.Text(
            '笔记',
            style: pw.TextStyle(
              fontSize: 6.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
              font: fontBold,
            ),
          ),
          pw.SizedBox(height: 2),
          if (rendered['note'] != null)
            pw.Image(
              pw.MemoryImage((rendered['note'] as Map<String, dynamic>)['bytes'] as Uint8List),
              width: ((rendered['note'] as Map<String, dynamic>)['width'] as double) * scaleFactor,
            )
          else
            pw.Text(
              mistake.note ?? '',
              style: pw.TextStyle(fontSize: 6, height: 1.2, font: fontRegular),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('笔记汇总'),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _mistakes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.doc_text_fill,
                          size: 80,
                          color: AppColors.textTertiary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '暂无笔记',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '在错题详情页添加笔记，即可在此处查看和导出。',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // 导出PDF按钮
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          onPressed: _exportPdf,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.share, size: 20),
                              SizedBox(width: 8),
                              Text(
                                '导出为PDF',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 笔记列表
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _mistakes.length,
                          itemBuilder: (context, index) {
                            final mistake = _mistakes[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          mistake.subject?.displayName ?? '未知学科',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        mistake.createdAt.toString().split(' ')[0],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // 题目内容（一行显示）
                                  if (mistake.questionId != null && _questions[mistake.questionId]?.content != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              '题目',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.accent,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: MathMarkdownText(
                                              text: _questions[mistake.questionId]!.content,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: AppColors.textSecondary,
                                                height: 1.4,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFCE7F3).withOpacity(0.8), // pink-100 浅粉背景
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          '笔记',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFF472B6), // pink-400 浅粉文字
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          mistake.note ?? '',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: AppColors.textPrimary,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

