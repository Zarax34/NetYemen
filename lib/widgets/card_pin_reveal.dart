// lib/widgets/card_pin_reveal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/purchase_model.dart';
import '../providers/app_providers.dart';
import '../utils/app_theme.dart';

/// يعرض رقم كرت عملية شراء مكتملة — مموّهاً (`12****89`) حتى يُلمَس، ثم
/// يكشفه صريحاً مع زر نسخ. الرقم لا يُخزَّن إلا في ذاكرة هذه الودجت خلال
/// عمرها، ولا يُطلب من الخادم إلا مرة واحدة لكل ظهور للودجت.
class CardPinReveal extends ConsumerStatefulWidget {
  final String purchaseId;

  const CardPinReveal({super.key, required this.purchaseId});

  @override
  ConsumerState<CardPinReveal> createState() => _CardPinRevealState();
}

class _CardPinRevealState extends ConsumerState<CardPinReveal> {
  String? _pin;
  bool _visible = false;
  bool _loading = false;
  String? _error;

  Future<void> _reveal() async {
    if (_pin != null) {
      setState(() => _visible = true);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(supabaseServiceProvider);
      final result = await service.revealPurchaseCard(widget.purchaseId);
      if (!mounted) return;
      setState(() {
        _pin = result.cardPin;
        _visible = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر كشف رقم الكرت. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _hide() => setState(() => _visible = false);

  Future<void> _copy() async {
    final pin = _pin;
    if (pin == null) return;
    await Clipboard.setData(ClipboardData(text: pin));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ رقم الكرت')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_error != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _error!,
              style: const TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'إعادة المحاولة',
            onPressed: _reveal,
          ),
        ],
      );
    }

    final pin = _pin;
    final display = pin == null ? 'اضغط للكشف' : (_visible ? pin : maskCardPin(pin));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SelectableText(
            display,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(
            pin == null
                ? Icons.visibility_outlined
                : (_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            size: 18,
          ),
          tooltip: pin == null ? 'كشف الرقم' : (_visible ? 'إخفاء الرقم' : 'إظهار الرقم'),
          onPressed: pin == null ? _reveal : (_visible ? _hide : _reveal),
        ),
        if (pin != null)
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18),
            tooltip: 'نسخ الرقم',
            onPressed: _copy,
          ),
      ],
    );
  }
}
