# LiveKit Voice Assistant (Flutter)

All-platform Flutter app (iOS, Android, Web, Desktop) that connects to a LiveKit Agent and streams microphone audio. Includes:

- User selection screen
- Animated background main screen
- Floating reusable voice assistant FAB (configurable position, toggle/hold modes)
- LiveKit connection with token fetch via `/getToken`
- Animated equalizer when mic is active
- `.env` driven config

## Setup

1. Create your `.env` based on `.env.example`:

```
cp .env.example .env
# edit values if needed
```

- `LIVEKIT_URL` e.g. `ws://localhost:7880`
- `API_BASE_URL` e.g. `http://localhost:3000`

2. Install dependencies:

```
flutter pub get
```

## Run

- Web/Desktop (no extra SDKs):
```
flutter run -d linux   # or -d web
```

- Android/iOS: set up platform SDKs per Flutter docs.

## Notes

- Token is requested via POST `${API_BASE_URL}/getToken` with JSON body `{ userId, userName }`.
- Selected user metadata is attached to the LiveKit local participant attributes.
- Floating button position is configurable via `AssistantPosition`.
