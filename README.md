# TaskManager App (Flutter)

## Environment

`.env.example`을 복사하여 `.env` 또는 `.env.production` 생성:

```bash
cp .env.example .env.production
```

## Development

기본값 `http://localhost:8000/api/v1` 사용:

```bash
flutter run -d chrome
```

커스텀 URL 사용 시:

```bash
flutter run --dart-define-from-file=.env
```

## Build

```bash
# Web
flutter build web --dart-define-from-file=.env.production

# APK
flutter build apk --dart-define-from-file=.env.production

# iOS
flutter build ios --dart-define-from-file=.env.production
```
