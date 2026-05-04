# EV Ride App - Flutter Project Structure

## 📁 Complete Folder Structure

```
EV_Ride_App/
├── android/                    # Android platform files
│   ├── app/
│   ├── build.gradle
│   └── settings.gradle
│
├── lib/                        # Main source code
│   └── src/
│       ├── core/               # Core utilities & configuration
│       │   ├── constants/      # App constants (API URLs, keys)
│       │   ├── theme/          # App theme (colors, fonts, styles)
│       │   ├── utils/          # Utility functions
│       │   └── errors/         # Custom exceptions & error handling
│       │
│       ├── data/               # Data layer
│       │   ├── models/         # Data models (User, Ride, Vehicle)
│       │   ├── providers/      # State management (Provider/Bloc)
│       │   ├── repositories/   # Data repositories
│       │   └── services/       # API services (HTTP, Socket)
│       │
│       └── presentation/      # UI layer
│           ├── controllers/    # Business logic controllers
│           ├── pages/          # App screens
│           │   ├── auth/       # Login, Register, OTP
│           │   ├── home/       # Home dashboard
│           │   ├── rides/      # Ride booking, tracking
│           │   ├── profile/    # User profile, KYC
│           │   └── earnings/   # Driver earnings
│           └── widgets/        # Reusable UI components
│
├── pubspec.yaml                # Dependencies
├── analysis_options.yaml       # Linting rules
└── README.md
```

## 🎯 Architecture Pattern: Clean Architecture

```
┌─────────────────────────────────────────────────────┐
│                 PRESENTATION LAYER                   │
│    Pages (UI) ←→ Controllers (Logic) ←→ Widgets     │
└─────────────────────────────────────────────────────┘
                          ↓ ↑
┌─────────────────────────────────────────────────────┐
│                    DATA LAYER                        │
│  Models → Repositories → Services (API/Socket)      │
└─────────────────────────────────────────────────────┘
                          ↓ ↑
┌─────────────────────────────────────────────────────┐
│                    CORE LAYER                        │
│    Constants, Theme, Utils, Error Handling          │
└─────────────────────────────────────────────────────┘
```

## 📦 Key Dependencies (pubspec.yaml)

- **State Management**: provider / flutter_bloc
- **HTTP Client**: dio
- **Local Storage**: shared_preferences, hive
- **Maps**: google_maps_flutter
- **Real-time**: socket_io_client
- **Push Notifications**: firebase_messaging
- **Image Handling**: cached_network_image
- **Forms**: flutter_form_builder

## 🚀 Getting Started

1. Navigate to project: `cd EV_Ride_App`
2. Get dependencies: `flutter pub get`
3. Run app: `flutter run`

## 📱 Features Module Mapping

| Feature | Location |
|---------|----------|
| Authentication | `presentation/pages/auth/` |
| Home Dashboard | `presentation/pages/home/` |
| Ride Booking | `presentation/pages/rides/` |
| Profile/KYC | `presentation/pages/profile/` |
| Earnings | `presentation/pages/earnings/` |
| Reusable UI | `presentation/widgets/` |
| API Calls | `data/services/` |
| Data Models | `data/models/` |
