import '../data/models/booking_model.dart';

/// Shared by the customer slot picker and the owner's walk-in booking
/// screen so both compute availability the same way against real bookings.
enum SlotStatus { available, booked, pending, past, blocked }

SlotStatus computeSlotStatus({
  required DateTime date,
  required int hour,
  required List<BookingModel> bookedSlots,
  Set<int> blockedHours = const {},
}) {
  final slotStart = DateTime(date.year, date.month, date.day, hour % 24);
  if (slotStart.isBefore(DateTime.now())) return SlotStatus.past;
  if (blockedHours.contains(hour)) return SlotStatus.blocked;

  final slotEnd = slotStart.add(const Duration(hours: 1));
  for (final b in bookedSlots) {
    final overlaps =
        slotStart.isBefore(b.endDateTime) && slotEnd.isAfter(b.startDateTime);
    if (!overlaps) continue;
    return b.status == BookingStatus.confirmed ||
            b.status == BookingStatus.completed
        ? SlotStatus.booked
        : SlotStatus.pending;
  }
  return SlotStatus.available;
}
