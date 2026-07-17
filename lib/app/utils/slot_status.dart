import '../data/models/booking_model.dart';

/// Shared by the customer slot picker and the owner's walk-in booking
/// screen so both compute availability the same way against real bookings.
enum SlotStatus { available, booked, pending, past }

SlotStatus computeSlotStatus({
  required DateTime date,
  required int hour,
  required List<BookingModel> bookedSlots,
}) {
  final slotStart = DateTime(date.year, date.month, date.day, hour % 24);
  if (slotStart.isBefore(DateTime.now())) return SlotStatus.past;

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
