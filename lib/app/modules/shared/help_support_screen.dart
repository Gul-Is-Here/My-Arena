import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _whatsapp = '+923001234567';
  static const _email = 'support@myarena.pk';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: Get.back,
        ),
        title: Text(
          'Help & Support',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // ── Contact us ─────────────────────────────────────────────
          _sectionHeader('Contact Us'),
          _contactCard(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'WhatsApp Support',
            subtitle: _whatsapp,
            color: const Color(0xFF25D366),
            onTap: () => _launch('https://wa.me/${_whatsapp.replaceAll('+', '')}'),
          ),
          _contactCard(
            icon: Icons.email_outlined,
            label: 'Email Support',
            subtitle: _email,
            color: AppColors.secondary,
            onTap: () => _launch('mailto:$_email'),
          ),

          const SizedBox(height: 28),

          // ── FAQs ───────────────────────────────────────────────────
          _sectionHeader('Frequently Asked Questions'),
          const SizedBox(height: 8),
          ..._faqs.map((faq) => _FaqTile(question: faq[0], answer: faq[1])),

          const SizedBox(height: 28),

          // ── Submit a ticket ────────────────────────────────────────
          _sectionHeader('Still need help?'),
          const SizedBox(height: 8),
          _actionTile(
            icon: Icons.confirmation_number_outlined,
            label: 'My Support Tickets',
            onTap: () => Get.toNamed(AppRoutes.customerTickets),
          ),
          const SizedBox(height: 8),
          _actionTile(
            icon: Icons.add_circle_outline_rounded,
            label: 'Submit New Ticket',
            onTap: () => Get.toNamed(AppRoutes.submitTicket),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static const _faqs = [
    [
      'How do I book an arena?',
      'Browse arenas from the Home tab, pick a court and time slot, pay the deposit, and your booking is confirmed once the owner approves.',
    ],
    [
      'How long does deposit approval take?',
      'Most owners approve within 1–2 hours. You will receive a push notification as soon as the status changes.',
    ],
    [
      'Can I cancel a booking?',
      'Yes. Open the booking from your Bookings tab, tap Cancel, and provide your bank details for a refund. Cancellation fees may apply depending on how close to the booking date you cancel.',
    ],
    [
      'How do I check in on the day?',
      'Show the QR code on your booking detail to the venue staff or let the owner scan it in the app.',
    ],
    [
      'My deposit screenshot was rejected — what do I do?',
      'Re-submit a clear screenshot of your bank transfer. Make sure the amount, date, and account number are visible.',
    ],
    [
      'How do I add a new arena (for owners)?',
      'From your Owner Dashboard, tap Add Arena and follow the 3-step wizard: Basic Info → Photos → Location.',
    ],
    [
      'How do I boost my arena?',
      'Go to your arena detail page and tap Boost. Select a duration, pay the fee, and submit a payment screenshot. Admin will approve it shortly.',
    ],
  ];

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      );

  Widget _contactCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(subtitle,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: AppColors.textSecondary),
            ],
          ),
        ),
      );

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    )),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: AppColors.primary),
            ],
          ),
        ),
      );

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _open
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  widget.answer,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
