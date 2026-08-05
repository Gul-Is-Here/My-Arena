import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../data/models/ticket_model.dart';
import '../../services/ticket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

const _bg = AppColors.background;
const _surface = AppColors.surface;
const _surfaceLow = AppColors.elevated;
const _outline = AppColors.border;
const _cyan = AppColors.primary;
const _greenFixed = AppColors.success;
const _amber = AppColors.warning;
const _red = AppColors.error;
const _onSurface = AppColors.textPrimary;
const _onSurfaceVar = AppColors.textSecondary;
const _onCyan = AppColors.onPrimary;

const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Owner support tickets — list of own tickets + FAB to raise new one.
class OwnerTicketsScreen extends StatefulWidget {
  const OwnerTicketsScreen({super.key});

  @override
  State<OwnerTicketsScreen> createState() => _OwnerTicketsScreenState();
}

class _OwnerTicketsScreenState extends State<OwnerTicketsScreen> {
  final _service = TicketService();
  final _tickets = <TicketModel>[].obs;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _sub = _service.userTickets(uid).listen((list) => _tickets.assignAll(list));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: Get.back,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _outline),
                      ),
                      child: const Icon(Icons.arrow_back, color: _onSurface, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Support Tickets',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineMedium.copyWith(color: _onSurface, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                if (_tickets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.support_agent_outlined, color: _onSurfaceVar, size: 52),
                        const SizedBox(height: 12),
                        Text('No tickets yet', style: AppTextStyles.titleMedium.copyWith(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Tap + to raise a support request', style: AppTextStyles.bodySmall.copyWith(color: _onSurfaceVar, fontSize: 13)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: _tickets.length,
                  itemBuilder: (_, i) => _TicketCard(ticket: _tickets[i]),
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _cyan,
        foregroundColor: _onCyan,
        icon: const Icon(Icons.add),
        label: Text('New Ticket', style: AppTextStyles.button.copyWith(fontWeight: FontWeight.w700, color: _onCyan)),
        onPressed: () => _showCreateSheet(context),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateTicketSheet(service: _service),
    );
  }
}

// ── Ticket card ─────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;
  const _TicketCard({required this.ticket});

  Color _statusColor(TicketStatus s) {
    switch (s) {
      case TicketStatus.open:
        return _amber;
      case TicketStatus.inProgress:
        return _cyan;
      case TicketStatus.resolved:
        return _greenFixed;
      case TicketStatus.waitingForCustomer:
        return _amber;
      case TicketStatus.closed:
        return _onSurfaceVar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(ticket.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.subject,
                  style: AppTextStyles.titleMedium.copyWith(color: _onSurface, fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(ticket.status.label, style: AppTextStyles.caption.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          if (ticket.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              ticket.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(color: _onSurfaceVar, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.tag, color: _onSurfaceVar, size: 13),
              const SizedBox(width: 4),
              Text(ticket.category, style: AppTextStyles.caption.copyWith(color: _onSurfaceVar, fontSize: 11.5)),
              const Spacer(),
              Text(_fmtDate(ticket.createdAt), style: AppTextStyles.caption.copyWith(color: _onSurfaceVar, fontSize: 11.5)),
            ],
          ),
          if (ticket.replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latest reply — ${ticket.replies.last.senderName}',
                    style: AppTextStyles.caption.copyWith(color: _cyan, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ticket.replies.last.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(color: _onSurfaceVar, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Create ticket bottom sheet ───────────────────────────────────────────────

class _CreateTicketSheet extends StatefulWidget {
  final TicketService service;
  const _CreateTicketSheet({required this.service});

  @override
  State<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<_CreateTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'Booking Issue';
  bool _submitting = false;

  static const _categories = [
    'Booking Issue',
    'Payment',
    'Arena Verification',
    'Technical Problem',
    'Account',
    'Other',
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final user = AuthController.to.currentUser.value;
      await widget.service.createTicket(TicketModel(
        id: '',
        subject: _subjectCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        raisedByUid: FirebaseAuth.instance.currentUser?.uid ?? '',
        raisedByName: user?.name ?? 'Owner',
        raisedByRole: 'owner',
        category: _category,
        createdAt: DateTime.now(),
      ));
      if (mounted) {
        Navigator.of(context).pop();
        Get.snackbar('Ticket Raised', 'We\'ll respond shortly.',
            backgroundColor: _surface, colorText: _greenFixed,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        Get.snackbar('Error', e.toString(),
            backgroundColor: _surface, colorText: _red,
            snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: _outline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Raise Support Ticket', style: AppTextStyles.titleLarge.copyWith(color: _onSurface, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            // Category
            Text('Category', style: AppTextStyles.caption.copyWith(color: _onSurfaceVar, fontSize: 12)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _surfaceLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _outline),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _category,
                  dropdownColor: _surface,
                  style: AppTextStyles.bodyMedium.copyWith(color: _onSurface),
                  isExpanded: true,
                  onChanged: (v) { if (v != null) setState(() => _category = v); },
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Subject
            TextFormField(
              controller: _subjectCtrl,
              style: AppTextStyles.bodyMedium.copyWith(color: _onSurface),
              decoration: _inputDec('Subject'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            // Description
            TextFormField(
              controller: _descCtrl,
              style: AppTextStyles.bodyMedium.copyWith(color: _onSurface),
              decoration: _inputDec('Describe your issue'),
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cyan,
                  foregroundColor: _onCyan,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _onCyan))
                    : Text('Submit Ticket', style: AppTextStyles.button.copyWith(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.bodyMedium.copyWith(color: _onSurfaceVar),
    filled: true,
    fillColor: _surfaceLow,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _outline)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _outline)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cyan)),
  );
}
