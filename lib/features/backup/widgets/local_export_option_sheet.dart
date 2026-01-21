import 'package:flutter/material.dart';
import '../../../../icons/lucide_adapter.dart';
import '../../../../l10n/app_localizations.dart';

class LocalExportOptionSheet extends StatelessWidget {
  const LocalExportOptionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.white10 : const Color(0xFFF7F7F9);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.backupPageExportToFile,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _ActionCard(
              color: cardColor,
              icon: Lucide.Share,
              title: l10n.settingsPageShare, // "Share"
              subtitle: l10n.backupPageExportToFileShareSubtitle, // Reuse subtitle or create new one
              onTap: () => Navigator.of(context).pop(LocalExportAction.share),
            ),
            const SizedBox(height: 10),
            _ActionCard(
              color: cardColor,
              icon: Lucide.Download,
              title: l10n.backupPageSave, // "Save"
              subtitle: l10n.backupPageExportToFileSaveSubtitle,
              onTap: () => Navigator.of(context).pop(LocalExportAction.save),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

enum LocalExportAction { share, save }

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.color, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _TactileRow(
      pressedScale: 0.98,
      onTap: onTap,
      builder: (pressed) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overlay = pressed ? (isDark ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.05)) : Colors.transparent;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Color.alphaBlend(overlay, color),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.18)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: cs.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
                  ],
                ),
              ),
              const Icon(Lucide.ChevronRight, size: 18),
            ],
          ),
        );
      },
    );
  }
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({required this.builder, this.onTap, this.pressedScale = 1.0});
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final double pressedScale;
  @override
  State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;
  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTapCancel: widget.onTap == null ? null : () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              widget.onTap!.call();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.builder(_pressed),
      ),
    );
  }
}
