# Fluxpay

WhatsApp-native subscription billing for African SMB merchants.

## Stack

- Flutter (Android + Linux)
- Backend API: https://pawahub-production.up.railway.app
- WhatsApp bot: https://zooming-bravery-production-f6f7.up.railway.app

## Development

```bash
flutter pub get
flutter run
flutter build apk --debug
flutter build linux
```

## CI/CD

GitHub Actions builds the APK on every push to `main`. Download the artifact from the Actions tab.
