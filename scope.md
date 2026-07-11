# Arena Management App — Scope Document
**Flutter · Firebase · GetX**
Version 1.0 | Multi-purpose Event Venue | July 2026

---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Tech Stack](#2-tech-stack)
3. [App Structure](#3-app-structure)
4. [Roles & Permissions](#4-roles--permissions)
5. [Phase 1 — Auth & Roles](#5-phase-1--auth--roles)
6. [Phase 2 — Owner Module](#6-phase-2--owner-module)
7. [Phase 3 — Booking System](#7-phase-3--booking-system)
8. [Phase 4 — Chat & Admin Panel](#8-phase-4--chat--admin-panel)
9. [Phase 5 — Tournaments & Events](#9-phase-5--tournaments--events)
10. [Firestore Collections Summary](#10-firestore-collections-summary)
11. [Flutter Packages](#11-flutter-packages)
12. [Timeline](#12-timeline)
13. [UI / Design System](#13-ui--design-system)

---

## 1. Project Overview

Arena Management App ek cross-platform Flutter application hai jo multi-purpose event venues ko digitize karta hai. Customers arenas discover kar sakte hain, courts book kar sakte hain, tournaments mein register kar sakte hain aur owners apni arenas manage kar sakte hain — sab kuch ek hi app mein.

### Key Decisions
- **Single App** with role-based navigation (no separate apps)
- **One Firebase project** — sab roles same backend use karein
- **4 Roles:** Customer, Owner, Staff, Admin
- **JazzCash** payment (manual screenshot) for now, gateway baad mein

---

## 2. Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| Frontend | Flutter 3.x | Cross-platform UI (iOS, Android) |
| State Management | GetX | Reactive state, DI, routing |
| Database | Firebase Firestore | Real-time NoSQL database |
| Auth | Firebase Auth | Email, Google, Phone OTP |
| Storage | Firebase Storage | Images, documents, screenshots |
| Functions | Cloud Functions | Notifications, scheduled tasks |
| Push Notifications | FCM | Booking alerts, confirmations |
| Maps | Google Maps Flutter | Location picker, arena discovery |
| Geo Queries | Geoflutterfire | 30km radius search |
| Charts | fl_chart | Dashboard analytics |

---

## 3. App Structure

```
Single App — Role Based Navigation

Login → Firebase Auth → Check role in Firestore
            ├── customer  → CustomerDashboard
            ├── owner     → OwnerDashboard
            ├── staff     → StaffDashboard
            └── admin     → AdminDashboard
```

### Folder Structure
```
lib/
├── main.dart
├── app/
│   ├── bindings/
│   ├── controllers/
│   ├── data/
│   │   ├── models/
│   │   ├── providers/
│   │   └── repositories/
│   ├── modules/
│   │   ├── auth/
│   │   ├── owner/
│   │   ├── booking/
│   │   ├── chat/
│   │   ├── admin/
│   │   ├── staff/
│   │   └── tournaments/
│   ├── routes/
│   ├── theme/
│   └── utils/
```

---

## 4. Roles & Permissions

| Role | Signup | Created By | Access |
|---|---|---|---|
| Customer | Self signup ✅ | Khud | Arena discovery, booking, tournaments |
| Owner | Self signup ✅ | Khud | Arena management, booking management |
| Staff | ❌ No self signup | Admin | Approvals, support chat |
| Admin | ❌ Manual | Firestore manually | Full platform control |

---

## 5. Phase 1 — Auth & Roles

**Duration: 2 Weeks**

### Login Methods
- Email & Password
- Google Sign-In
- Phone OTP

### Screens
```
├── SplashScreen          → role check & auto redirect
├── OnboardingScreen      → first time only
├── LoginScreen
├── SignupScreen          → Customer & Owner only
│    └── RoleSelectStep   → "Customer hun ya Owner?"
├── PhoneOtpScreen
├── ForgotPasswordScreen
└── ProfileSetupScreen    → name, avatar, phone
```

### Signup Rules
- **Customer & Owner:** Self signup with role selection
- **Staff:** Admin creates account manually
- **Admin:** Directly set in Firestore

### Firestore — users/{uid}
```
uid: string
name: string
email: string
phone: string
role: 'customer' | 'owner' | 'staff' | 'admin'
avatar: string            ← Firebase Storage URL
isActive: boolean
createdAt: timestamp
lastLogin: timestamp
```

### GetX — AuthController
```dart
RxBool isLoading = false.obs
RxString error = ''.obs
Rx<UserModel?> currentUser = Rxn<UserModel>()

signUpWithEmail()
signInWithEmail()
signInWithGoogle()
signInWithPhone()
sendOtp()
verifyOtp()
resetPassword()
signOut()
```

### Route Guard
```
SplashScreen:
→ Not logged in       → LoginScreen
→ role: customer      → CustomerDashboard
→ role: owner         → OwnerDashboard
→ role: staff         → StaffDashboard
→ role: admin         → AdminDashboard
```

---

## 6. Phase 2 — Owner Module

**Duration: 3 Weeks**

### Sub-Features
1. Owner Dashboard
2. Arena + Court Setup
3. Customer Arena Discovery (30km)
4. Boost / Feature Arena
5. Event Promotion Request
6. Arena ON/OFF Toggle

---

### 6.1 Owner Dashboard

**Screens:** OwnerDashboardScreen

**Widgets:**
- Revenue graph — daily/weekly/monthly (fl_chart)
- Stats cards: Total bookings, Active courts, Earnings, Pending approvals
- Recent activity feed
- Pending approval status badge

---

### 6.2 Arena & Court Setup

**Screens:**
```
├── MyArenasScreen
├── AddArenaScreen (Multi-step)
│    ├── Step 1: Basic Info (name, description)
│    ├── Step 2: Images Upload (multiple)
│    ├── Step 3: Location Picker (Google Maps search)
│    ├── Step 4: Add Courts
│    │    └── AddCourtBottomSheet
│    │         ├── Court type: football|padel|indoor|cricket|other
│    │         ├── Capacity
│    │         ├── Price per hour
│    │         └── Time slots (start time → end time)
│    └── Step 5: Review & Submit
└── ArenaDetailScreen (Owner view)
     ├── ON/OFF toggle
     ├── Edit option
     ├── Courts list
     ├── Boost button
     └── Event Promote button
```

**Arena Status Flow:**
```
Owner submits → 'pending'
Admin/Staff reviews → 'approved' / 'rejected'
If approved → visible to customers
```

**Firestore — arenas/{arenaId}**
```
ownerId: string
name: string
description: string
images: string[]
location:
    address: string
    lat: number
    lng: number
status: 'pending'|'approved'|'rejected'|'off'
isActive: boolean            ← Owner ON/OFF
isFeatured: boolean
featuredUntil: timestamp
createdAt: timestamp
approvedBy: string
```

**Firestore — arenas/{arenaId}/courts/{courtId}**
```
arenaId: string
name: string
type: 'football'|'padel'|'indoor'|'cricket'|'other'
capacity: number
pricePerHour: number
images: string[]
timeSlots:
    startTime: '08:00'
    endTime: '23:00'
advanceBookingDays: number
isActive: boolean
```

---

### 6.3 Customer Arena Discovery

**Screens:**
```
├── HomeScreen
│    ├── GPS location detect
│    ├── Featured arenas (top)
│    └── Nearby arenas list
├── ArenaListScreen
│    ├── Map View + List View toggle
│    └── Filters: court type, price, distance
└── ArenaDetailScreen (Customer view)
     ├── Images carousel
     ├── Courts list with prices
     ├── Map location
     └── Book Now → Phase 3
```

**30km Radius Query:**
```dart
// geoflutterfire package
GeoFlutterFire geo = GeoFlutterFire();

geo.collection(collectionRef: arenasRef)
   .within(
     center: customerGeoPoint,
     radius: 30,
     field: 'position'
   )
// Only status: 'approved' + isActive: true show karo
```

---

### 6.4 Boost / Feature Arena

**Screens:**
```
├── BoostRequestScreen
│    ├── Duration select: 1 week | 2 weeks | 1 month
│    ├── Price display (from admin settings)
│    ├── JazzCash number display
│    ├── Screenshot upload
│    └── Submit
└── BoostStatusScreen
     └── pending | approved | rejected
```

**Firestore — boostRequests/{requestId}**
```
arenaId: string
ownerId: string
type: 'boost' | 'event'
duration: '1_week'|'2_week'|'1_month'
price: number
paymentScreenshot: string
accountUsed: string
status: 'pending'|'approved'|'rejected'
eventDetails: object?
createdAt: timestamp
```

**Firestore — settings/boostPricing**
```
1_week: number
2_week: number
1_month: number
```

---

### 6.5 Event Promotion Request

Same flow as Boost with additional event details form:
- Event name, description, date, expected attendees
- Payment via JazzCash + screenshot
- Admin approve kare → event promoted

---

### 6.6 Arena ON/OFF Toggle

- Owner ArenaDetailScreen pe toggle
- `isActive: false` → customers ko "Unavailable" dikhe
- Existing confirmed bookings unaffected rahein

---

## 7. Phase 3 — Booking System

**Duration: 3 Weeks**

### Rules
- **Booking Type:** Hourly (1hr, 2hr, 3hr...)
- **Confirmation:** Owner/Staff manually approve kare
- **Who can book:** Customer, Owner (walk-in), Staff
- **Deposit:** Admin-set % advance, remaining at venue
- **Cancellation:** 1 hour before allowed, 20% deposit deducted

---

### Booking Statuses
```
pending_deposit     → Booked, deposit awaited
deposit_submitted   → Screenshot uploaded
confirmed           → Owner/Staff approved
rejected            → Owner rejected
completed           → Event done
cancelled           → Cancelled
refund_pending      → Awaiting refund
refund_sent         → Owner sent refund
refund_confirmed    → Customer confirmed receipt
```

---

### Screens
```
CUSTOMER
├── CourtDetailScreen
├── BookingSlotScreen
│    ├── Calendar widget
│    └── Hourly slot grid
│         ├── 🟢 Available
│         ├── 🔴 Booked
│         └── 🟡 Pending
├── BookingSummaryScreen
│    ├── Total amount
│    ├── Deposit (X%)
│    └── Remaining at venue
├── DepositPaymentScreen
│    ├── JazzCash number
│    ├── Screenshot upload
│    └── Submit
├── BookingConfirmationScreen
├── MyBookingsScreen
│    └── Tabs: Upcoming | Past | Cancelled
└── CancellationScreen
     ├── Deduction breakdown
     ├── Refund amount
     └── Customer bank account form

OWNER / STAFF
├── PendingBookingsScreen
│    ├── Deposit screenshot view
│    └── Approve / Reject
├── AllBookingsScreen
├── ManualBookingScreen    ← walk-in customers
└── RefundManagementScreen
     ├── Customer account details
     └── Upload refund screenshot
```

---

### Booking Flow
```
Customer → Select Court → Date → Hours
→ Summary (Total / Deposit / Remaining)
→ JazzCash screenshot upload
→ status: 'deposit_submitted'
→ FCM → Owner notified
→ Owner approves → status: 'confirmed'
→ FCM → Customer "Booking Confirmed ✅"
```

### Cancellation Flow
```
Customer → Cancel request
→ Check: booking time - now > 1 hour? ✅
→ Deduct 20% from deposit
→ Show refund amount
→ Customer fills bank account details
→ status: 'cancelled' + 'refund_pending'
→ FCM → Owner notified
→ Owner sends refund → uploads screenshot
→ status: 'refund_sent'
→ FCM → Customer notified
→ Customer confirms → status: 'refund_confirmed'
```

### Double Booking Prevention
```dart
// Firestore Transaction
FirebaseFirestore.instance.runTransaction((tx) async {
  // Check overlapping bookings same court + date
  // If overlap found → throw Exception
  // If safe → create booking
});
```

### Firestore — bookings/{bookingId}
```
bookingId: string
arenaId: string
courtId: string
customerId: string
bookedBy: string
bookedByRole: 'customer'|'owner'|'staff'
date: timestamp
startTime: '14:00'
endTime: '17:00'
totalHours: number
pricePerHour: number
totalAmount: number
depositAmount: number
remainingAmount: number
status: string
depositPayment:
    screenshot: string
    accountUsed: string
    submittedAt: timestamp
cancellation:
    requestedAt: timestamp
    deductionPercent: 20
    refundAmount: number
    customerAccount:
        bankName: string
        accountNumber: string
    refundScreenshot: string
    refundStatus: 'pending'|'sent'|'confirmed'
confirmedBy: string
createdAt: timestamp
```

### Firestore — settings/booking
```
depositPercent: 30
cancellationDeductPercent: 20
minCancelHoursBefore: 1
jazzCashNumber: '03XX-XXXXXXX'
```

---

## 8. Phase 4 — Chat & Admin Panel

**Duration: 2 Weeks**

---

### 8.1 Chat System

### Chat Types
```
1. Booking Chat      → Customer ↔ Owner (booking k against)
2. Owner Support     → Owner ↔ Admin/Staff
3. Customer Support  → Customer ↔ Admin/Staff
Admin: Monitor all chats + intervene
```

### Chat Features
- Real-time messaging (Firestore live)
- Text + Images + Documents
- Unread badge count
- Read receipts
- Admin monitoring (read-only + can intervene)

### Screens
```
CUSTOMER
├── MyChatsScreen
│    ├── Booking Chats tab
│    └── Support tab
└── ChatRoomScreen
     ├── Real-time messages
     ├── Text input
     ├── Image picker
     └── Document attach

OWNER
├── MyChatsScreen
└── ChatRoomScreen (reused)

ADMIN
├── AllChatsScreen
│    ├── Booking Chats list
│    ├── Owner Support list
│    └── Customer Support list
├── ChatRoomScreen (monitor + reply)
└── SupportInboxScreen
     ├── Open tickets
     ├── Assign to staff
     └── Close resolved
```

### Firestore — chats/{chatId}
```
type: 'booking'|'owner_support'|'customer_support'
participants: string[]
bookingId: string?
lastMessage: string
lastMessageAt: timestamp
isReadBy: map              ← {uid: timestamp}
status: 'active'|'closed'
createdAt: timestamp
```

### Firestore — chats/{chatId}/messages/{msgId}
```
senderId: string
senderRole: string
type: 'text'|'image'|'document'
content: string
fileName: string?
isRead: boolean
createdAt: timestamp
```

---

### 8.2 Admin Panel

### Admin Dashboard
- Stats: Total arenas, Today's bookings, Revenue, Open support tickets
- Revenue graph (daily/weekly/monthly)
- Recent bookings list
- Pending approvals badge

### Admin Screens
```
├── AdminDashboardScreen
├── Arena Management
│    ├── PendingArenasScreen      ← Approve/Reject
│    └── AllArenasScreen          ← Force OFF, Remove
├── Boost Management
│    ├── PendingBoostRequestsScreen
│    └── ActiveBoostsScreen
├── User Management
│    ├── AllUsersScreen           ← Ban/Unban, Change role
│    └── StaffManagementScreen    ← Add/Deactivate staff
├── Booking Oversight
│    ├── AllBookingsScreen
│    └── RefundOversightScreen
├── Chat & Support               ← AllChatsScreen
├── Tournament Approvals         ← Phase 5
├── Settings
│    ├── depositPercent
│    ├── cancellationDeductPercent
│    ├── minCancelHoursBefore
│    ├── jazzCashNumber
│    └── boostPricing
└── Audit Logs
     ├── All admin/staff actions
     └── Filter + Export CSV
```

### Staff Panel (Limited Access)
```
├── StaffDashboardScreen
├── Arena Approvals
├── Booking Approvals
├── Boost Approvals
└── Support Chat (reply only)
```

### Firestore — auditLogs/{logId}
```
actorId: string
actorRole: string
action: string
targetId: string
targetType: string
timestamp: timestamp
metadata: map
```

---

## 9. Phase 5 — Tournaments & Events

**Duration: 3 Weeks**

### Rules
- Owner apni arena pe tournament create kare → Admin approve kare
- Admin platform-wide tournament create kare → No approval needed
- Formats: Single Elimination + Round Robin
- Participation: Individual ya Team (owner decide kare)
- Registration: Free ya Paid (owner decide kare)
- Live scores + public leaderboard

---

### Tournament Statuses
```
draft → pending_approval → approved
→ registration_open → ongoing → completed
rejected
```

### Screens
```
CUSTOMER
├── TournamentsHomeScreen
│    ├── Featured tournaments
│    ├── Near me tournaments
│    └── Filters: sport, free/paid, date
├── TournamentDetailScreen
├── RegistrationScreen
│    ├── Individual: name, phone
│    └── Team: team name + members
├── RegistrationPaymentScreen   ← if paid
├── MyTournamentsScreen
│    └── QR entry pass per tournament
├── BracketScreen (PUBLIC live)
│    ├── Elimination: bracket tree
│    └── Round Robin: points table
└── LeaderboardScreen (PUBLIC live)

OWNER
├── MyTournamentsScreen
├── CreateTournamentScreen (5 steps)
│    ├── Step 1: Basic info + banner
│    ├── Step 2: Format + participation type
│    ├── Step 3: Schedule + court assign
│    ├── Step 4: Registration fee
│    └── Step 5: Review & Submit
└── TournamentManageScreen
     ├── Registrations list + payment verify
     ├── Generate Bracket button
     ├── Schedule matches
     ├── Live score entry
     └── Mark complete

ADMIN
├── PendingTournamentsScreen    ← Approve/Reject
├── AllTournamentsScreen
└── CreateTournamentScreen      ← No approval needed
```

---

### Tournament Flows

**Creation:**
```
Owner creates → pending_approval
→ FCM Admin notified
→ Admin approve/reject
→ If approved → registration_open
→ Customers can register
```

**Registration:**
```
Customer registers (individual/team)
→ Free → Confirmed directly → QR generated
→ Paid → JazzCash screenshot → Owner verify
         → Confirmed → QR generated
```

**Bracket & Live:**
```
Owner: Generate Bracket
→ Auto shuffle participants
→ Matches scheduled on courts
→ Public bracket visible

Match played → Owner/Staff enter scores
→ Firestore update → Real-time bracket update
→ Winner auto advances (elimination)
→ Points table auto updates (round robin)
→ FCM → All participants notified
```

---

### Firestore — tournaments/{tournamentId}
```
createdBy: string
createdByRole: 'owner'|'admin'
arenaId: string?
name: string
description: string
bannerImage: string
sport: string
format: 'elimination'|'round_robin'
participationType: 'individual'|'team'
maxParticipants: number
registeredCount: number
registrationFee: number
isFree: boolean
startDate: timestamp
endDate: timestamp
registrationDeadline: timestamp
status: string
approvedBy: string?
prizeDetails: string
createdAt: timestamp
```

### Firestore — registrations/{regId}
```
tournamentId: string
userId: string
type: 'individual'|'team'
playerName: string?
teamName: string?
members: [{name, phone, position}]
paymentScreenshot: string?
paymentStatus: 'free'|'pending'|'verified'
qrCode: string
status: 'pending'|'confirmed'|'rejected'
registeredAt: timestamp
```

### Firestore — brackets/{bracketId}
```
tournamentId: string
format: string
rounds: [
  {
    roundNumber: number,
    matches: [
      {
        matchId: string,
        participant1: {id, name},
        participant2: {id, name},
        scheduledAt: timestamp,
        courtId: string,
        score1: number?,
        score2: number?,
        winner: string?,
        status: 'scheduled'|'ongoing'|'completed'
      }
    ]
  }
]
updatedAt: timestamp
```

### Firestore — leaderboards/{tournamentId}
```
format: string
rankings: [
  {
    position: number,
    participantId: string,
    participantName: string,
    played: number,
    won: number,
    lost: number,
    points: number,
    goalsFor: number?,
    goalsAgainst: number?
  }
]
updatedAt: timestamp
```

---

## 10. Firestore Collections Summary

| Collection | Purpose |
|---|---|
| users | All users (4 roles) |
| arenas | Arena details |
| arenas/{id}/courts | Courts under each arena |
| bookings | All bookings |
| boostRequests | Boost & event promo requests |
| chats | Chat rooms |
| chats/{id}/messages | Messages per chat |
| tournaments | Tournament details |
| registrations | Tournament registrations |
| brackets | Tournament brackets |
| leaderboards | Live rankings |
| auditLogs | Admin/staff actions log |
| settings | App-wide config (deposit %, JazzCash no.) |

---

## 11. Flutter Packages

| Package | Purpose | Phase |
|---|---|---|
| get | GetX: state, routing, DI | 1 |
| firebase_core | Firebase init | 1 |
| firebase_auth | Authentication | 1 |
| cloud_firestore | Database | 1 |
| firebase_storage | File uploads | 1 |
| firebase_messaging | Push notifications | 1 |
| google_sign_in | Google auth | 1 |
| cached_network_image | Image caching | 1 |
| image_picker | Image uploads | 2 |
| google_maps_flutter | Maps & location | 2 |
| geolocator | GPS location | 2 |
| geoflutterfire | 30km radius query | 2 |
| table_calendar | Booking calendar | 3 |
| fl_chart | Dashboard charts | 4 |
| qr_flutter | QR code generation | 5 |
| mobile_scanner | QR code scanning | 5 |
| intl | Date/time formatting | 1 |
| connectivity_plus | Network status | 1 |
| file_picker | Document upload in chat | 4 |

---

## 12. Timeline

| Phase | Feature | Duration |
|---|---|---|
| Phase 1 | Auth + Roles + Navigation | 2 weeks |
| Phase 2 | Owner Module + Arena + Discovery | 3 weeks |
| Phase 3 | Booking System + Payments | 3 weeks |
| Phase 4 | Chat + Admin + Staff Panel | 2 weeks |
| Phase 5 | Tournaments + Live Scores | 3 weeks |
| **Total** | | **13 weeks (~3 months)** |

---

## 13. UI / Design System

### Development Approach
> **UI First, Backend Later** — Pehle saari screens design hongi (dummy data ke sath), phir Firebase backend integrate hoga. State management GetX se hoga.

### Theme
| Item | Decision |
|---|---|
| Theme Mode | Both — Light & Dark (toggle) |
| Design Style | Bold & Sporty |
| Language | English |
| Color Scheme | Electric Blue + Black |

### Color Palette
```
Primary:        #2979FF   (Electric Blue)
Primary Dark:   #0D47A1
Accent:         #00E5FF   (Cyan glow)
Black:          #0A0A0A   (Dark backgrounds)
Dark Surface:   #121212
Light Surface:  #FFFFFF
Light BG:       #F5F7FA
Success:        #00C853
Error:          #FF1744
Warning:        #FFAB00
```

### Theme Structure (GetX)
```
lib/app/theme/
├── app_colors.dart        ← color constants
├── app_text_styles.dart   ← typography
├── app_theme.dart         ← light + dark ThemeData
└── theme_controller.dart  ← GetX theme toggle (persisted)
```

### Design Order (Phase-wise UI)
```
1. Phase 1 UI → Splash, Onboarding, Login, Signup,
                OTP, Forgot Password, Profile Setup
2. Phase 2 UI → Owner Dashboard, Arena Setup (5 steps),
                Customer Home, Arena Discovery, Boost screens
3. Phase 3 UI → Booking flow, Slot grid, Payment,
                My Bookings, Cancellation
4. Phase 4 UI → Chat screens, Admin Panel, Staff Panel
5. Phase 5 UI → Tournaments, Brackets, Leaderboard, QR
```

### UI Rules
- Sab screens pehle **dummy/mock data** ke sath banein
- Controllers mein placeholder logic (baad mein Firebase attach hoga)
- Reusable widgets banao: `AppButton`, `AppTextField`, `AppCard`, `StatusBadge`, `LoadingOverlay`
- Bold typography, rounded corners (16px), sporty gradients on CTAs
- Dark theme default, toggle available in settings

---

## Security Rules Strategy

| Collection | Read | Write |
|---|---|---|
| users | Owner / Admin | Owner (own profile) / Admin |
| arenas | Authenticated | Owner (own) / Admin |
| bookings | Owner / Customer (own) / Staff | Customer (create) / Owner+Staff (update) |
| boostRequests | Owner (own) / Admin | Owner (create) / Admin (update) |
| chats | Participants only | Participants only |
| tournaments | All authenticated | Owner (own) / Admin |
| registrations | Owner / Customer (own) | Customer (create) / Owner (update) |
| auditLogs | Admin only | Cloud Functions only |
| settings | All authenticated | Admin only |

> All sensitive writes (payment status, refunds, audit logs) are handled via Cloud Functions only — no client-side writes allowed.

---

*Arena Management App — SCOPE.md v1.0 | July 2026*