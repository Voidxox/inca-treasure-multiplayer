import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/socket_service.dart' show MessageKind;

extension Reveal on Widget {
  Widget reveal(int index) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 360 + index * 70),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        ),
        child: this,
      );
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .11),
              Colors.black.withValues(alpha: .2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .16)),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 34, offset: Offset(0, 18)),
          ],
        ),
        child: child,
      );
}

class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.primary = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onTap;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => setState(() => pressed = true),
        onTapCancel: () => setState(() => pressed = false),
        onTapUp: (_) => setState(() => pressed = false),
        child: AnimatedScale(
          scale: pressed ? .96 : 1,
          duration: const Duration(milliseconds: 90),
          child: FilledButton.icon(
            onPressed: widget.onTap,
            icon: Icon(widget.icon, size: 20),
            label: Text(
              widget.label,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              backgroundColor: widget.primary ? gold : Colors.white.withValues(alpha: .1),
              foregroundColor: widget.primary ? const Color(0xff211407) : bone,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      );
}

class FancyField extends StatelessWidget {
  const FancyField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white.withValues(alpha: .06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .14)),
          ),
        ),
      );
}

class SceneTitle extends StatelessWidget {
  const SceneTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              color: bone,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: muted)),
        ],
      );
}

class RoomCodePlate extends StatelessWidget {
  const RoomCodePlate({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [gold.withValues(alpha: .2), jade.withValues(alpha: .12)],
        ),
        border: Border.all(color: gold.withValues(alpha: .35)),
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: gold,
          fontSize: 38,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
        ),
      ),
    );
  }
}

class GlowPill extends StatelessWidget {
  const GlowPill({
    super.key,
    required this.title,
    required this.subtitle,
    this.active = false,
  });

  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? jade : Colors.white24),
          boxShadow: active ? [BoxShadow(color: jade.withValues(alpha: .2), blurRadius: 22)] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: gold,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
          ],
        ),
      );
}

class StatusToast extends StatelessWidget {
  const StatusToast({super.key, required this.message, this.kind = MessageKind.info});

  final String message;
  final MessageKind kind;

  @override
  Widget build(BuildContext context) {
    // 按语义配色：错误偏红、成功偏 jade、信息偏 bone，不再让成功提示显示为错误红。
    final (color, icon) = switch (kind) {
      MessageKind.error => (const Color(0xffffb09f), Icons.error_outline_rounded),
      MessageKind.success => (jade, Icons.check_circle_outline_rounded),
      MessageKind.info => (bone, Icons.info_outline_rounded),
    };
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    ).reveal(0);
  }
}
