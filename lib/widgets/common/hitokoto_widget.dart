import 'package:flutter/cupertino.dart';
import '../../config/colors.dart';
import '../../services/hitokoto_service.dart';
import '../../models/hitokoto.dart';

/// 一言组件 - 简单的居中灰字显示
class HitokotoWidget extends StatefulWidget {
  const HitokotoWidget({super.key});

  @override
  State<HitokotoWidget> createState() => _HitokotoWidgetState();
}

class _HitokotoWidgetState extends State<HitokotoWidget> {
  Hitokoto? _hitokoto;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHitokoto();
  }

  Future<void> _loadHitokoto() async {
    setState(() {
      _isLoading = true;
    });

    final hitokoto = await HitokotoService.getHitokoto(
      categories: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'k'], // 除了抖机灵(l)之外的所有类型
    );

    if (mounted) {
      setState(() {
        _hitokoto = hitokoto;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 8, bottom: 16),
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    if (_hitokoto == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(
          left: 32,
          right: 32,
          top: 8,
          bottom: 8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 一言正文
            Text(
              _hitokoto!.hitokoto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textTertiary,
                height: 1.6,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            // 出处
            Text(
              '—— ${_hitokoto!.fromWho != null ? '${_hitokoto!.fromWho}《${_hitokoto!.from}》' : _hitokoto!.from}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textDisabled,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

