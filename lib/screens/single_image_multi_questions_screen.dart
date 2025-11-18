import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../services/mistake_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/common/loading_state_widget.dart';
import '../widgets/common/selectable_list_item.dart';
import '../widgets/common/image_preview_grid.dart';
import '../widgets/common/camera_action_buttons.dart';
import '../widgets/common/local_image_preview.dart';
import 'mistake_analysis_progress_screen.dart';

/// 单图识别多题屏幕
/// 支持拍摄一张整页试卷图片，识别并裁剪多个题目
class SingleImageMultiQuestionsScreen extends StatefulWidget {
  const SingleImageMultiQuestionsScreen({super.key});

  @override
  State<SingleImageMultiQuestionsScreen> createState() =>
      _SingleImageMultiQuestionsScreenState();
}

enum _Step {
  selectImage,      // 步骤1: 选择/拍摄图片
  detecting,        // 步骤2: 检测题目
  selectQuestions,  // 步骤3: 选择题目
  cropping,         // 步骤4: 裁剪题目
  preview,          // 步骤5: 预览确认
  submitting,       // 步骤6: 提交分析
}

class _SingleImageMultiQuestionsScreenState
    extends State<SingleImageMultiQuestionsScreen> {
  final MistakeService _mistakeService = MistakeService();
  final ImagePicker _picker = ImagePicker();

  _Step _currentStep = _Step.selectImage;
  
  // 步骤1: 图片
  String? _originalImagePath;
  String? _originalImageFileId;
  
  // 步骤2: 检测到的题目列表
  List<String> _detectedQuestions = [];
  String? _detectionError;
  
  // 步骤3: 选中的题目
  final Set<String> _selectedQuestions = {};
  
  // 步骤4: 裁剪进度
  int _croppingCurrent = 0;
  int _croppingTotal = 0;
  String? _croppingError;
  
  // 步骤5: 裁剪后的图片ID列表
  List<String> _croppedImageIds = [];
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.background,
        middle: const Text(
          '单图识别多题',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () {
            if (_currentStep == _Step.selectImage) {
              Navigator.of(context).pop();
            } else {
              _goBack();
            }
          },
          color: AppColors.textPrimary,
        ),
      ),
      child: SafeArea(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentStep) {
      case _Step.selectImage:
        return _buildSelectImageStep();
      case _Step.detecting:
        return _buildDetectingStep();
      case _Step.selectQuestions:
        return _buildSelectQuestionsStep();
      case _Step.cropping:
        return _buildCroppingStep();
      case _Step.preview:
        return _buildPreviewStep();
      case _Step.submitting:
        return _buildSubmittingStep();
    }
  }

  // 步骤1: 选择/拍摄图片
  Widget _buildSelectImageStep() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            
            // 提示文字
            const Text(
              '一页多题模式',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              '拍摄整页试卷，系统将自动识别并裁剪多个题目',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            
            // 图片预览
            if (_originalImagePath != null) ...[
              LocalImagePreview(
                imagePath: _originalImagePath!,
                height: 300,
              ),
              const SizedBox(height: 24),
            ],
            
            // 相机操作按钮
            CameraActionButtons(
              onTakePicture: _takePicture,
              onPickFromGallery: _pickFromGallery,
              hasImage: _originalImagePath != null,
            ),
            
            // 下一步按钮
            if (_originalImagePath != null) ...[
              const SizedBox(height: 48),
              CupertinoButton.filled(
                onPressed: _startDetection,
                child: const Text('开始识别题目'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 步骤2: 检测题目中
  Widget _buildDetectingStep() {
    return LoadingStateWidget(
      message: '正在识别题目...',
      errorMessage: _detectionError,
      onRetry: _detectionError != null ? _startDetection : null,
    );
  }

  // 步骤3: 选择题目
  Widget _buildSelectQuestionsStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 原图缩略图
                if (_originalImagePath != null) ...[
                  LocalImagePreview(
                    imagePath: _originalImagePath!,
                    height: 150,
                  ),
                  const SizedBox(height: 24),
                ],
                
                // 题目列表
                const Text(
                  '请选择需要记录的题目',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                
                if (_detectedQuestions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      '未检测到题目',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ..._detectedQuestions.map((question) {
                    final isSelected = _selectedQuestions.contains(question);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SelectableListItem(
                        title: question,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedQuestions.remove(question);
                            } else {
                              _selectedQuestions.add(question);
                            }
                          });
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        
        // 底部按钮
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: CupertinoButton.filled(
              onPressed: _selectedQuestions.isEmpty
                  ? null
                  : _startCropping,
              child: Text(
                '确认裁剪 (已选${_selectedQuestions.length}题)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 步骤4: 裁剪中
  Widget _buildCroppingStep() {
    return LoadingStateWidget(
      message: '正在裁剪第 $_croppingCurrent/$_croppingTotal 题...',
      errorMessage: _croppingError,
      onRetry: _croppingError != null ? _startCropping : null,
    );
  }

  // 步骤5: 预览确认
  Widget _buildPreviewStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '预览裁剪结果',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                
                ImagePreviewGrid(
                  imageIds: _croppedImageIds,
                  onDelete: (index) {
                    setState(() {
                      _croppedImageIds.removeAt(index);
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        
        // 底部按钮
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: CupertinoButton.filled(
              onPressed: _croppedImageIds.isEmpty
                  ? null
                  : _submitForAnalysis,
              child: Text(
                '提交分析 (${_croppedImageIds.length}题)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 步骤6: 提交中
  Widget _buildSubmittingStep() {
    return const LoadingStateWidget(
      message: '正在提交分析...',
    );
  }

  // 拍照
  Future<void> _takePicture() async {
    HapticFeedback.mediumImpact();
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );

      if (image != null && mounted) {
        setState(() {
          _originalImagePath = image.path;
          _originalImageFileId = null;
          _detectedQuestions.clear();
          _selectedQuestions.clear();
          _croppedImageIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('拍照失败', '无法访问相机，请检查相机权限设置');
      }
    }
  }

  // 从相册选择
  Future<void> _pickFromGallery() async {
    HapticFeedback.mediumImpact();
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image != null && mounted) {
        setState(() {
          _originalImagePath = image.path;
          _originalImageFileId = null;
          _detectedQuestions.clear();
          _selectedQuestions.clear();
          _croppedImageIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('选择失败', '无法访问相册，请检查相册权限设置');
      }
    }
  }

  // 开始检测题目
  Future<void> _startDetection() async {
    if (_originalImagePath == null) return;

    setState(() {
      _currentStep = _Step.detecting;
      _detectionError = null;
    });

    try {
      // 1. 上传图片
      final imageFileId = await _mistakeService.uploadMistakeImage(_originalImagePath!);
      
      if (!mounted) return;

      setState(() {
        _originalImageFileId = imageFileId;
      });

      // 2. 调用检测function
      final questions = await _mistakeService.detectQuestions(imageFileId);

      if (!mounted) return;

      if (questions.isEmpty) {
        setState(() {
          _detectionError = '未检测到题目，请确保图片清晰且包含题目';
        });
        return;
      }

      setState(() {
        _detectedQuestions = questions;
        _selectedQuestions.clear();
        _currentStep = _Step.selectQuestions;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detectionError = '检测失败: ${e.toString()}';
      });
    }
  }

  // 开始裁剪
  Future<void> _startCropping() async {
    if (_originalImageFileId == null || _selectedQuestions.isEmpty) return;

    setState(() {
      _currentStep = _Step.cropping;
      _croppingCurrent = 0;
      _croppingTotal = _selectedQuestions.length;
      _croppingError = null;
      _croppedImageIds.clear();
    });

    try {
      final selectedList = _selectedQuestions.toList();
      final croppedIds = <String>[];

      // 并行裁剪所有选中的题目
      for (var i = 0; i < selectedList.length; i++) {
        if (!mounted) return;

        setState(() {
          _croppingCurrent = i + 1;
        });

        try {
          final croppedId = await _mistakeService.cropQuestion(
            _originalImageFileId!,
            selectedList[i],
          );
          croppedIds.add(croppedId);
        } catch (e) {
          print('裁剪题目 ${selectedList[i]} 失败: $e');
          // 继续裁剪其他题目
        }
      }

      if (!mounted) return;

      if (croppedIds.isEmpty) {
        setState(() {
          _croppingError = '所有题目裁剪失败，请重试';
        });
        return;
      }

      setState(() {
        _croppedImageIds = croppedIds;
        _currentStep = _Step.preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _croppingError = '裁剪失败: ${e.toString()}';
      });
    }
  }

  // 提交分析
  Future<void> _submitForAnalysis() async {
    if (_croppedImageIds.isEmpty) return;

    setState(() {
      _currentStep = _Step.submitting;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProfile = authProvider.userProfile;
      
      if (userProfile == null) {
        throw Exception('用户未登录');
      }
      
      final userId = userProfile.id;

      // 为每个裁剪图片创建mistake_record
      final questions = _croppedImageIds.map((id) => [id]).toList();
      
      await _mistakeService.createMistakeFromQuestions(
        userId: userId,
        questions: questions,
      );

      if (!mounted) return;

      // 导航到分析进度页面
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (context) => MistakeAnalysisProgressScreen(
            questions: questions,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('提交失败', e.toString());
      setState(() {
        _currentStep = _Step.preview;
      });
    }
  }

  // 返回上一步
  void _goBack() {
    switch (_currentStep) {
      case _Step.selectImage:
        Navigator.of(context).pop();
        break;
      case _Step.detecting:
        setState(() {
          _currentStep = _Step.selectImage;
          _detectionError = null;
        });
        break;
      case _Step.selectQuestions:
        setState(() {
          _currentStep = _Step.selectImage;
        });
        break;
      case _Step.cropping:
        setState(() {
          _currentStep = _Step.selectQuestions;
          _croppingError = null;
        });
        break;
      case _Step.preview:
        setState(() {
          _currentStep = _Step.selectQuestions;
        });
        break;
      case _Step.submitting:
        setState(() {
          _currentStep = _Step.preview;
        });
        break;
    }
  }

  // 显示错误对话框
  Future<void> _showErrorDialog(String title, String message) async {
    return showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

