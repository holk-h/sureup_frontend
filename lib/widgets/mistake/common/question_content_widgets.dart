import 'package:flutter/cupertino.dart';
import '../../../config/api_config.dart';
import '../../../config/colors.dart';
import '../../common/math_markdown_text.dart';

class ExtractedImagesWidget extends StatelessWidget {
  final List<String>? extractedImages;

  const ExtractedImagesWidget({super.key, this.extractedImages});

  @override
  Widget build(BuildContext context) {
    final validImageIds = extractedImages
        ?.where((id) => id.isNotEmpty)
        .toList();

    if (validImageIds == null || validImageIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: validImageIds.map((imageId) {
        final imageUrl =
            '${ApiConfig.endpoint}/storage/buckets/${ApiConfig.extractedImagesBucketId}/files/$imageId/view?project=${ApiConfig.projectId}';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: const BoxConstraints(maxHeight: 120),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 120,
                  color: AppColors.background,
                  child: const Center(child: CupertinoActivityIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }).toList(),
    );
  }
}

class OptionsListWidget extends StatelessWidget {
  final List<String> options;

  const OptionsListWidget({super.key, required this.options});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final label = String.fromCharCode(65 + index); // A, B, C, D...

        String cleanedOption = option;
        final prefixPattern = RegExp(r'^[A-Z]\.?\s*');
        if (prefixPattern.hasMatch(option)) {
          cleanedOption = option.replaceFirst(prefixPattern, '');
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MathMarkdownText(
                  text: cleanedOption,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                  scrollable: true,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

