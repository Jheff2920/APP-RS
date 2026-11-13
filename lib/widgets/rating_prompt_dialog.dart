import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';

import '../l10n/app_lang.dart';
import '../services/engagement_prompts_store.dart';
import '../services/redpos/redpos_config.dart';
import '../services/redpos/redpos_links.dart';
import '../theme.dart';
import 'ui_kit.dart';

/// Diálogo de valoración con estrellas animadas. 4-5★ van a la reseña real
/// de Google Play; 1-3★ abren un comentario privado (no público) por correo.
/// Ninguna rama bloquea nada de la app; ambas terminan en [markRatingDone].
Future<void> showRatingPromptDialog(
  BuildContext context, {
  EngagementPromptsStore? store,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RatingPromptDialog(store: store ?? EngagementPromptsStore()),
  );
}

enum _Step { stars, feedback, thanks }

class _RatingPromptDialog extends StatefulWidget {
  const _RatingPromptDialog({required this.store});

  final EngagementPromptsStore store;

  @override
  State<_RatingPromptDialog> createState() => _RatingPromptDialogState();
}

class _RatingPromptDialogState extends State<_RatingPromptDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  final _commentCtrl = TextEditingController();
  var _step = _Step.stars;
  var _rating = 0;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _later() async {
    await widget.store.markRatingLater();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _selectStar(int value) async {
    setState(() => _rating = value);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    if (value >= 4) {
      setState(() => _step = _Step.thanks);
      await widget.store.markRatingDone();
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        } else {
          await review.openStoreListing();
        }
      } catch (_) {
        // La reseña nativa puede no estar disponible (cuota de Google,
        // emulador, etc.); el agradecimiento ya se mostró de todas formas.
      }
    } else {
      setState(() => _step = _Step.feedback);
    }
  }

  Future<void> _sendFeedback() async {
    setState(() => _sending = true);
    await widget.store.markRatingDone();
    if (!mounted) return;
    await openRedPosLink(
      context,
      RedPosConfig.feedbackMailtoUri(stars: _rating, comment: _commentCtrl.text),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _skipFeedback() async {
    await widget.store.markRatingDone();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ScaleTransition(
      scale: CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack),
      child: FadeTransition(
        opacity: _entrance,
        child: AlertDialog(
          scrollable: true,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: switch (_step) {
                _Step.stars => _StarsStep(
                    key: const ValueKey('stars'),
                    rating: _rating,
                    onSelect: _selectStar,
                    onLater: _later,
                  ),
                _Step.feedback => _FeedbackStep(
                    key: const ValueKey('feedback'),
                    controller: _commentCtrl,
                    sending: _sending,
                    onSend: _sendFeedback,
                    onSkip: _skipFeedback,
                  ),
                _Step.thanks => _ThanksStep(key: const ValueKey('thanks'), l: l),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StarsStep extends StatelessWidget {
  const _StarsStep({
    super.key,
    required this.rating,
    required this.onSelect,
    required this.onLater,
  });

  final int rating;
  final ValueChanged<int> onSelect;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(child: IconTile(icon: Icons.print_outlined, size: 56)),
        const SizedBox(height: 14),
        Text(
          l('¿Cómo te fue con RedPOS?', 'How has RedPOS worked for you?'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          l(
            'Tu opinión ayuda a mejorar la app. Toca una estrella.',
            'Your opinion helps improve the app. Tap a star.',
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                iconSize: 40,
                onPressed: () => onSelect(i),
                icon: AnimatedScale(
                  scale: i <= rating ? 1.18 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i <= rating ? AppColors.warn : AppColors.inkSoft,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onLater,
          child: Text(l('Después', 'Later')),
        ),
      ],
    );
  }
}

class _FeedbackStep extends StatelessWidget {
  const _FeedbackStep({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onSkip,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(child: IconTile(icon: Icons.chat_bubble_outline_rounded, size: 56, color: AppColors.warn)),
        const SizedBox(height: 14),
        Text(
          l('¿Qué podemos mejorar?', 'What can we improve?'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          l(
            'Esto nos llega solo a nosotros, no se publica en Play.',
            'This only reaches us, it is not published on Play.',
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          maxLines: 3,
          enabled: !sending,
          decoration: InputDecoration(
            hintText: l('Cuéntanos qué pasó (opcional)', 'Tell us what happened (optional)'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: sending ? null : onSkip,
                child: Text(l('No, gracias', 'No, thanks')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: sending ? null : onSend,
                child: sending
                    ? const ButtonSpinner(color: Colors.white)
                    : Text(l('Enviar', 'Send')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ThanksStep extends StatelessWidget {
  const _ThanksStep({super.key, required this.l});

  final L l;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Align(
          child: IconTile(icon: Icons.favorite_rounded, size: 56, color: AppColors.ok),
        ),
        const SizedBox(height: 14),
        Text(
          l('¡Gracias por tu apoyo!', 'Thanks for your support!'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Align(
          child: TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l('Cerrar', 'Close')),
          ),
        ),
      ],
    );
  }
}
