import 'dart:async';
import 'dart:io';
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
import '../widgets/common/camera_action_buttons.dart';
import '../widgets/common/local_image_preview.dart';
import 'mistake_preview_screen.dart';

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
  submitting,       // 步骤5: 提交分析
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
        // 原图显示（圆角卡片，尺寸匹配图片）
        Flexible(
          child: _originalImagePath != null
              ? SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingL),
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - 
                            AppConstants.spacingL * 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_originalImagePath!),
                          fit: BoxFit.contain,
                  ),
                      ),
                    ),
                  ),
                )
              : const SizedBox(),
        ),
        
        // 题目标签选择区域
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(
              top: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                const Text(
                  '请选择需要记录的题目',
                  style: TextStyle(
                  fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              const SizedBox(height: 12),
                
                if (_detectedQuestions.isEmpty)
                  const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _detectedQuestions.map((question) {
                    final isSelected = _selectedQuestions.contains(question);
                    return GestureDetector(
                        onTap: () {
                        HapticFeedback.selectionClick();
                          setState(() {
                            if (isSelected) {
                              _selectedQuestions.remove(question);
                            } else {
                              _selectedQuestions.add(question);
                            }
                          });
                        },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
          decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.15)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.divider,
                            width: isSelected ? 2 : 1.5,
            ),
          ),
                        child: Text(
                          question,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              
              const SizedBox(height: 16),
              
              // 确认按钮（无白色背景）
              SafeArea(
            top: false,
                child: SizedBox(
                  width: double.infinity,
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

  // 步骤5: 提交中
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
      
      // 1. 创建一个包含所有题目的裁剪任务
      final taskId = await _mistakeService.createCropTasks(
        _originalImageFileId!,
        selectedList,
      );

      if (!mounted) return;

      // 2. 监听任务状态更新
      StreamSubscription<Map<String, dynamic>>? subscription;
      
      subscription = _mistakeService.watchCropTask(taskId).listen((task) {
        if (!mounted) return;
        
        final status = task['status'] as String;
        final totalCount = task['totalCount'] as int? ?? 0;
        final completedCount = task['completedCount'] as int? ?? 0;
        final croppedImageIds = (task['croppedImageIds'] as List<dynamic>?)?.cast<String>() ?? [];
        
        setState(() {
          _croppingTotal = totalCount;
          _croppingCurrent = completedCount;
          _croppedImageIds = croppedImageIds;
        });
        
        // 处理完成或失败
        if (status == 'completed') {
          subscription!.cancel();
          if (croppedImageIds.isEmpty) {
            setState(() {
              _croppingError = '所有题目裁剪失败，请重试';
            });
          } else {
            // 裁剪完成，直接提交分析
            _submitForAnalysis();
          }
        } else if (status == 'failed') {
          subscription!.cancel();
          final error = task['error'] as String? ?? '裁剪失败';
          if (croppedImageIds.isEmpty) {
            setState(() {
              _croppingError = error;
            });
          } else {
            // 部分成功，直接提交分析
            _submitForAnalysis();
          }
        }
      }, onError: (error) {
        if (!mounted) return;
        subscription!.cancel();
        setState(() {
          _croppingError = '监听任务更新失败: ${error.toString()}';
        });
      });

      // 等待任务完成或超时
      try {
        await _mistakeService.watchCropTask(taskId).firstWhere((task) {
          final status = task['status'] as String;
          return status == 'completed' || status == 'failed';
        }).timeout(
          const Duration(minutes: 5),
        );
      } on TimeoutException {
        if (!mounted) return;
        subscription.cancel();
        if (_croppedImageIds.isEmpty) {
          setState(() {
            _croppingError = '裁剪任务超时，请重试';
          });
        } else {
          // 部分成功，直接提交分析
          _submitForAnalysis();
        }
      } catch (e) {
        if (!mounted) return;
        subscription.cancel();
        setState(() {
          _croppingError = '裁剪失败: ${e.toString()}';
        });
      }
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

      // 为每个裁剪图片创建mistake_record（使用已上传的图片ID）
      final questions = _croppedImageIds.map((id) => [id]).toList();
      
      // 创建错题记录（图片已经上传，直接使用ID）
      final recordIds = await _mistakeService.createMistakeFromImageIds(
        userId: userId,
        imageIds: questions,
        userProfile: userProfile,
      );

      if (!mounted) return;

      // 直接跳转到预览页面（记录已创建，分析会自动开始）
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (context) => MistakePreviewScreen(
            mistakeRecordIds: recordIds,
            initialIndex: 0,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('提交失败', e.toString());
      setState(() {
        _currentStep = _Step.cropping;
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
      case _Step.submitting:
        setState(() {
          _currentStep = _Step.cropping;
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

