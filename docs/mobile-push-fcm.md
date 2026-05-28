# Mobile Push FCM Android

L'app Flutter usa Firebase Cloud Messaging per ricevere reminder calendario/eventi anche quando l'app Android e chiusa. Questo canale e separato dalle notifiche locali workout e dal foreground service runner.

## Flusso

1. L'utente fa login o la sessione viene ripristinata.
2. `MobilePushService` inizializza Firebase Messaging se Android e configurato.
3. Richiede permesso notifiche su Android 13+.
4. Legge il token FCM.
5. Registra il token su `POST /api/mobile/device-tokens`.
6. Su refresh token FCM, invia il nuovo token al backend.
7. Al logout prova `DELETE /api/mobile/device-tokens/{token}` e poi continua comunque il logout locale.

Il token FCM non e una password/JWT e non viene salvato in secure storage: Firebase lo fornisce quando serve. Il backend non riceve token auth dentro FCM.

## Setup Android

Dipendenze Flutter:

- `firebase_core`
- `firebase_messaging`

Il file Firebase Android va aggiunto localmente in:

```text
android/app/google-services.json
```

Il file e ignorato da git perche dipende dal progetto Firebase. Il plugin Gradle Google Services viene applicato solo se `google-services.json` esiste, cosi le build locali senza credenziali continuano a funzionare. Senza quel file, FCM resta disabilitato a runtime e l'app continua a usare le funzionalita esistenti.

## Foreground/background

- Foreground: se arriva `type=EVENT_REMINDER`, l'app mostra una notifica locale con titolo/body del messaggio.
- Background/terminated: Android mostra la notifica FCM inviata dal backend.
- Tap notifica: per ora apre l'app. La navigazione diretta alla giornata/evento e TODO.

Payload atteso:

```json
{
  "type": "EVENT_REMINDER",
  "eventId": "42",
  "eventDate": "2026-05-21",
  "startTime": "18:30"
}
```

## Differenza da Web Push e workout

- Web Push PWA: browser/service worker Vue, VAPID, subscription `endpoint`.
- FCM mobile: token dispositivo Android nativo, backend Firebase Admin SDK.
- Workout runner: foreground service Android per countdown live; non usa FCM e non deve chiamare backend direttamente.

## TODO

- Deep link alla giornata/evento dopo tap notifica.
- APNs/iOS: richiede configurazione Apple Developer/APNs e setup iOS dedicato.
- Eventuale fallback local scheduled con deduplica rispetto a FCM.
