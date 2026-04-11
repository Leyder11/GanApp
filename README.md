# GanApp Flutter

Aplicacion de gestion ganadera con arquitectura offline-first y sincronizacion con Firebase Functions/Firestore.

## Requisitos cubiertos

- RNF010: empaquetado para distribucion Android/iOS.
- RNF011: sincronizacion bidireccional offline-online (cola local + push/pull + auto-sync al reconectar).
- RNF012: visualizacion de estado de sincronizacion (online/offline, pendientes, ultima sync, estado sincronizando).

## Desarrollo local

1. Instalar dependencias:

```bash
flutter pub get
```

2. Ejecutar app:

```bash
flutter run
```

## Build Android (APK/AAB)

### Debug APK (pruebas rapidas)

```bash
flutter build apk --debug
```

### Release APK

```bash
flutter build apk --release
```

### Release AAB (Play Store)

```bash
flutter build appbundle --release
```

### Firma Android release

Crear `android/key.properties`:

```properties
storePassword=TU_STORE_PASSWORD
keyPassword=TU_KEY_PASSWORD
keyAlias=TU_KEY_ALIAS
storeFile=../keystore/tu_keystore.jks
```

Notas:
- Si existe `android/key.properties`, el build release usa esa firma.
- Si no existe, cae en firma debug para pruebas locales.

## Build iOS (IPA/TestFlight)

1. Compilar iOS release:

```bash
flutter build ios --release
```

2. Generar IPA:

```bash
flutter build ipa --release
```

3. Subir a TestFlight desde Xcode Organizer o Transporter.

Requisitos iOS:
- Cuenta Apple Developer activa.
- Bundle ID, certificados y provisioning profiles configurados.

## Sincronizacion offline-online (RNF011)

- Operaciones CRUD se guardan localmente cuando no hay red (cola SQLite).
- La app hace push/pull con backend al sincronizar.
- Cuando la conectividad regresa, se intenta sincronizacion automatica en background.
- Estrategia de conflictos: last-write-wins (la ultima escritura aplicada prevalece).

## Exportacion PDF offline

- Los reportes/fichas PDF se generan localmente.
- Se guardan en almacenamiento de la app (`documents/reports`) y luego se pueden compartir o imprimir.
