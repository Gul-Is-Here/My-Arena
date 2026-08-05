import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/customer_ticket_controller.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/ticket_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';

class SubmitTicketScreen extends StatefulWidget {
  const SubmitTicketScreen({super.key});

  @override
  State<SubmitTicketScreen> createState() => _SubmitTicketScreenState();
}

class _SubmitTicketScreenState extends State<SubmitTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _category = kTicketCategories.first;
  BookingModel? _selectedBooking;
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<CustomerTicketController>()) {
      Get.put(CustomerTicketController());
    }
    final c = CustomerTicketController.to;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: Get.back,
        ),
        title: Text('Submit a Ticket',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            )),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            // ── Header ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'Describe your issue clearly. Our team responds within 24 hours.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primary)),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Subject ────────────────────────────────────────────────
            _label('Subject *'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _subjectCtrl,
              hint: 'Brief summary of your issue',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),

            const SizedBox(height: 20),

            // ── Category ──────────────────────────────────────────────
            _label('Category *'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _category,
                  dropdownColor: AppColors.surface,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textPrimary),
                  isExpanded: true,
                  items: kTicketCategories
                      .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Description ────────────────────────────────────────────
            _label('Message / Description *'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _messageCtrl,
              hint: 'Describe your issue in detail…',
              maxLines: 6,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v.trim().length < 20) return 'Please provide more detail (min 20 chars)';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ── Related booking ────────────────────────────────────────
            _label('Related Booking (optional)'),
            const SizedBox(height: 8),
            Obx(() {
              // .toList() performs an observable read so Obx registers the RxList.
              final bookings = c.customerBookings.toList();
              return _BookingPicker(
                bookings: bookings,
                selected: _selectedBooking,
                onSelect: (b) => setState(() => _selectedBooking = b),
                onClear: () => setState(() => _selectedBooking = null),
              );
            }),

            const SizedBox(height: 36),

            // ── Submit ─────────────────────────────────────────────────
            AppButton(
              label: 'Submit Ticket',
              isLoading: _submitting,
              onPressed: () => _submit(c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary, fontWeight: FontWeight.w600));

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        style:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textGrey),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red)),
        ),
      );

  Future<void> _submit(CustomerTicketController c) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      TicketBookingSnapshot? snapshot;
      if (_selectedBooking != null) {
        final b = _selectedBooking!;
        snapshot = TicketBookingSnapshot(
          bookingId: b.id,
          arenaName: b.arenaName,
          courtName: b.courtName,
          date: b.date,
          timeRange: b.timeRange,
          status: b.status.key,
        );
      }
      final ticketId = await c.createTicket(
        subject: _subjectCtrl.text.trim(),
        description: _messageCtrl.text.trim(),
        category: _category,
        bookingId: _selectedBooking?.id,
        bookingSnapshot: snapshot,
      );
      Get.offNamed(AppRoutes.customerTicketDetail, arguments: ticketId);
      Get.snackbar(
        'Ticket Submitted',
        'We\'ll get back to you as soon as possible.',
        backgroundColor: AppColors.primary,
        colorText: Colors.black,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _submitting = false);
    }
  }
}

// ── Booking picker widget ──────────────────────────────────────────────────

class _BookingPicker extends StatefulWidget {
  final List<BookingModel> bookings;
  final BookingModel? selected;
  final void Function(BookingModel) onSelect;
  final VoidCallback onClear;

  const _BookingPicker({
    required this.bookings,
    required this.selected,
    required this.onSelect,
    required this.onClear,
  });

  @override
  State<_BookingPicker> createState() => _BookingPickerState();
}

class _BookingPickerState extends State<_BookingPicker> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selected != null) {
      return _selectedCard(widget.selected!);
    }
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.search, color: AppColors.textGrey, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Select a booking (optional)',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textGrey)),
          ),
          const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textGrey, size: 20),
        ]),
      ),
    );
  }

  Widget _selectedCard(BookingModel b) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(children: [
        const Icon(Icons.sports_soccer_outlined,
            color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.arenaName,
                style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
            Text(
                '${b.courtName} · ${DateFormat('dd MMM yyyy').format(b.date)} · ${b.timeRange}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textGrey)),
          ]),
        ),
        GestureDetector(
          onTap: widget.onClear,
          child: const Icon(Icons.close, color: AppColors.textGrey, size: 20),
        ),
      ]),
    );
  }

  void _showPicker(BuildContext context) {
    _searchCtrl.clear();
    _q = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              // Handle
              Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Booking',
                        style: AppTextStyles.titleLarge
                            .copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setSheet(() => _q = v.toLowerCase()),
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search bookings…',
                        hintStyle: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textGrey),
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textGrey),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Builder(builder: (_) {
                  final filtered = _q.isEmpty
                      ? widget.bookings
                      : widget.bookings
                          .where((b) =>
                              b.arenaName.toLowerCase().contains(_q) ||
                              b.courtName.toLowerCase().contains(_q) ||
                              b.id.toLowerCase().contains(_q))
                          .toList();
                  if (filtered.isEmpty) {
                    return Center(
                        child: Text('No bookings found',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textGrey)));
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) =>
                        _bookingItem(filtered[i]),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookingItem(BookingModel b) {
    final statusColor = _bookingStatusColor(b.status);
    return GestureDetector(
      onTap: () {
        widget.onSelect(b);
        Get.back();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.sports_soccer_outlined,
                color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${b.arenaName} · ${b.courtName}',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                    '${DateFormat('dd MMM yyyy').format(b.date)}  ${b.timeRange}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textGrey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(b.status.label,
                style: AppTextStyles.caption
                    .copyWith(color: statusColor, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  Color _bookingStatusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.completed:
        return Colors.blue;
      case BookingStatus.cancelled:
      case BookingStatus.rejected:
        return Colors.red;
      default:
        return AppColors.warning;
    }
  }
}
