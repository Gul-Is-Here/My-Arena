import '../data/models/booking_model.dart';

/// Shared by the customer slot picker and the owner's walk-in booking
/// screen so both compute availability the same way against real bookings.
enum SlotStatus { available, booked, pending, past, blocked }

/// Primary path: uses real-time [bookedHours] set from slotLocks stream.
/// A locked hour is shown as [booked]; if you also need the pending
/// distinction, pass [bookedSlots] alongside and it will be used to
/// classify the status further.
SlotStatus computeSlotStatus({
  required DateTime date,
  required int hour,
  required List<BookingModel> bookedSlots,
  Set<int> blockedHours = const {},
  Set<int> lockedHours = const {}, // real-time slotLocks hours
}) {
  final slotStart = DateTime(date.year, date.month, date.day, hour % 24);
  if (slotStart.isBefore(DateTime.now())) return SlotStatus.past;
  if (blockedHours.contains(hour)) return SlotStatus.blocked;

  // If the slotLocks stream says this hour is taken, it's definitively booked.
  if (lockedHours.contains(hour)) return SlotStatus.booked;

  // Fallback: derive from booking models (used when slotLocks not yet loaded).
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
