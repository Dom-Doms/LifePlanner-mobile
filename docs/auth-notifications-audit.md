# Audit auth e notifiche mobile

Data audit: 2026-05-21

Scope: app Flutter in `lifeplanner_mobile`. I progetti Vue e Spring sono stati consultati solo come riferimento funzionale; non sono stati modificati.

Nota sui riferimenti: il path `C:\Users\Domenico\IdeaProjects\LifePlanner-Back` non esiste nella workspace corrente. Il backend Spring consultato e' `C:\Users\Domenico\IdeaProjects\LifePlanner`. La specifica `docs/mobile-flutter-spec.md` non e' presente nel progetto Flutter; in `docs` era presente solo `flutter-todo.md`.

## 1. Stato attuale login persistence

Flusso login Flutter:

1. `LoginScreen` usa `AuthController.login`.
2. `AuthController.login` chiama `AuthApi.login`.
3. `AuthApi.login` fa `POST /auth/login` senza header auth.
4. La response contiene `token` e `user`, modellati da `AuthResponse`.
5. `AuthController._persistSession` applica il token in memoria e salva JSON `{"token": "...", "user": {...}}`.
6. `ApiClient.setToken` mantiene il token in memoria e aggiunge `Authorization: Bearer <token>` alle richieste autenticate.

Storage usato:

- Flutter non usa `flutter_secure_storage`.
- `SessionStorage` usa il MethodChannel `lifeplanner_mobile/session_storage`.
- Android salva in `SharedPreferences` con nome `lifeplanner_session` e chiave `session`.
- iOS salva in `UserDefaults.standard` con chiave `lifeplanner_session`.
- In test o piattaforme senza plugin, `SessionStorage` usa solo fallback in memoria.

Logout:

- `AuthController.logout` azzera token/user in memoria.
- Chiama `ApiClient.setToken(null)`.
- Chiama `SessionStorage.clearSession`.

Confronto Vue:

- `LifePlanner-Front/src/stores/authStore.ts` salva token e user in `window.localStorage` con chiave `life-planner-auth`.
- `src/api/httpClient.ts` mette `Authorization: Bearer <token>` tramite interceptor.
- Anche Vue non mostra un refresh token lato client.

Durata token:

- Backend `application.yml`: default locale `APP_JWT_EXPIRATION_SECONDS:86400`, quindi 24 ore.
- Backend `application-docker.yml`: default Docker `APP_JWT_EXPIRATION_SECONDS:3600`, quindi 1 ora, se non sovrascritto da env.
- `JwtTokenService` genera solo JWT con `expiresAt`; non risulta un refresh token.

Rischio concreto: utente riapre app dopo N giorni.

- Se il JWT e' ancora valido, Android/iOS ripristinano la sessione persistita e le API partono con token.
- Se il JWT e' scaduto, la prima verifica `/auth/me` fallisce con 401/403 e `AuthController` fa logout controllato.
- Se il token scade dopo 1 ora in produzione Docker e non esiste refresh token, l'app non puo restare autenticata per giorni senza nuovo login.

## 2. Stato attuale auth restore

Bootstrap Flutter:

1. `main.dart` crea `ApiClient`, `SessionStorage`, `LocalNotificationService`, API service e `AuthController`.
2. `LifePlannerApp.didChangeDependencies` chiama `AppScope.of(context).auth.restore()` una sola volta.
3. Finche `auth.restoring` e' true, `MaterialApp.home` mostra `_SplashScreen`.
4. Quando restore finisce:
   - se autenticato: apre `MainShell`;
   - se non autenticato: apre `LoginScreen`.

Restore attuale:

- `AuthController.restore` legge la sessione persistita.
- Decodifica token e user.
- Applica il token ad `ApiClient`.
- Chiama `refreshProfile`, quindi `GET /auth/me`.
- Su 401/403 fa logout.
- Su altri errori API mantiene la sessione cached e logga debug.
- Su JSON/storage corrotto fa logout.
- In `finally` mette `_restoring = false`.

Pagine e auth ready:

- Le schermate principali gia aspettano `deps.auth.waitUntilReady()` prima delle API:
  - `DayScreen`
  - `WeekScreen`
  - `CalendarScreen`
  - lista workout
  - dettaglio workout
  - editor workout
  - runner workout
- `waitUntilReady` ha timeout di 12 secondi. Dopo timeout la pagina continua e poi verifica `deps.auth.isAuthenticated`.

Race condition rilevata:

- Per le schermate principali il rischio e' ridotto: la home non monta `MainShell` finche restore non finisce, e i loader interni aspettano comunque `waitUntilReady`.
- Il punto debole e' la durata del token: senza refresh token, il restore dopo molti giorni porta correttamente a logout.

Proposta di fix pulito se serve:

- Se l'obiettivo e' restare loggati oltre la durata JWT, serve supporto backend a refresh token oppure una durata JWT piu lunga lato configurazione. Questo non va inventato nel mobile.
- Migliorare storage mobile usando `flutter_secure_storage` al posto di SharedPreferences/UserDefaults per il token.
- Aggiungere test unitari per `AuthController.restore` su sessione valida, token 401, errore rete temporaneo e storage corrotto.

## 3. Stato attuale reminder scheduling

Servizio notifiche Flutter:

- `LocalNotificationService` espone:
  - `requestPermission`
  - `areNotificationsEnabled`
  - `show`
  - `vibrate`
  - `vibrateForStepCompletion`
- Non espone:
  - `schedule`
  - `cancel`
  - `cancelByEvent`
  - `pendingNotifications`
  - gestione timezone
  - ID stabile per reminder evento

Android:

- `AndroidManifest.xml` contiene:
  - `INTERNET`
  - `POST_NOTIFICATIONS`
  - `VIBRATE`
- Non contiene:
  - `SCHEDULE_EXACT_ALARM`
  - `USE_EXACT_ALARM`
  - receiver di boot per rischedulare allarmi dopo riavvio.
- `MainActivity.kt` supporta MethodChannel per:
  - richiesta permesso notifiche;
  - stato permesso;
  - notifica immediata con `NotificationManager.notify`;
  - vibrazione foreground.
- Il channel Android `lifeplanner_workout_v2` ha vibrazione abilitata, ma viene usato solo per notifiche immediate.

iOS:

- `AppDelegate.swift` supporta MethodChannel per:
  - richiesta permesso;
  - stato permesso;
  - notifica immediata con `UNNotificationRequest` e `trigger: nil`;
  - storage sessione in `UserDefaults`.
- Non ci sono trigger calendar/time interval per notifiche future.
- Non c'e' API di cancellazione con identificatore stabile.

Quando vengono schedulati i promemoria:

- Alla creazione evento: Flutter invia `reminderEnabled` e `reminderMinutesBefore` al backend, ma non schedula notifiche locali.
- Alla modifica evento: stesso comportamento.
- Al caricamento calendario/giorno/settimana/mese: nessuna schedulazione locale.
- Al login/restore: nessuna schedulazione locale.
- Per workout runner: solo notifiche immediate durante la run in foreground.

Confronto Vue/backend:

- Vue usa Web Push browser:
  - `pushNotificationService.ts` registra una `PushSubscription` browser con endpoint, `p256dh`, `auth`.
  - `service-worker.ts` riceve eventi `push` e mostra notifiche.
- Backend `ReminderScheduler` gira ogni 60 secondi, cerca eventi con reminder abilitato tra oggi e domani e manda Web Push agli utenti destinatari.
- Backend non espone un endpoint FCM/APNs per app native.

Cosa succede se chiudo app:

- Le notifiche immediate gia emesse restano gestite dall'OS.
- Nessun reminder locale futuro viene programmato dalla app Flutter.
- Se esiste una subscription Web Push browser attiva per lo stesso utente, puo ricevere il push su browser/PWA, non sull'app nativa Flutter.

Cosa succede se riavvio telefono:

- Nessun alarm locale Flutter e' registrato.
- Non c'e' boot receiver Android per rischedulare notifiche future.
- Quindi il mobile non garantisce reminder dopo reboot.

Cosa succede se evento e' tra un mese:

- Flutter salva i campi reminder sul backend.
- Flutter non programma nulla localmente.
- Backend `ReminderScheduler` considerera' l'evento solo quando sara' tra oggi e domani.
- La notifica arrivera' solo ai canali Web Push registrati nel backend, non alla app Flutter nativa.

Limiti Android noti nel codice attuale:

- Nessun exact alarm.
- Nessun WorkManager/AlarmManager.
- Nessun receiver per boot completed.
- Nessuna lista pending notification.
- Nessuna deduplica/cancellazione locale per evento aggiornato/eliminato.

## 4. Stato attuale reminder per eventi futuri

Evento singolo:

- `EventFormSheet` crea il payload con `buildEventFormPayload`.
- `calendarEventRequest` include `reminderEnabled` e, solo se abilitato, `reminderMinutesBefore`.
- `PlanningApi.createEvent` e `updateEvent` inviano il payload a `/events`.
- Nessun codice Flutter calcola `eventDate + startTime - reminderMinutesBefore`.
- Nessun codice Flutter persiste localmente un reminder.

Risultato:

- I reminder futuri dipendono dal backend Web Push, non da local notifications mobile.
- Il mobile mostra il dato evento quando ricarica calendario/giornata, ma non pianifica avvisi futuri.

## 5. Stato attuale reminder per ricorrenze

Ricorrenza Flutter:

- Il form supporta `NONE`, `DAILY`, `WEEKLY`, `BIWEEKLY`, `MONTHLY`.
- Se ricorrenza non `NONE`, richiede `recurrenceUntil`.
- Il payload e' compatibile con Vue/backend.

Ricorrenza backend:

- `CalendarEventService.create` espande la ricorrenza creando eventi separati dal giorno iniziale fino a `recurrenceUntil`.
- Ogni evento creato riceve `reminderEnabled` e `reminderMinutesBefore`.
- `ReminderScheduler` lavora sugli eventi persistiti e non su una regola lato client.

Bug/rischio duplicati:

- Flutter oggi non crea duplicati locali perche non schedula nulla.
- Quando verra' aggiunta schedulazione locale, servono ID stabili per evitare duplicati a ogni reload.

Bug/rischio nessuna notifica futura:

- Certo lato Flutter nativo: nessuna notifica futura locale viene programmata.
- Probabile lato esperienza utente mobile: se l'utente usa solo app Flutter e non ha Web Push browser attivo, non ricevera' reminder evento/workout a app chiusa.

## 6. Problemi certi

1. La app Flutter non ha schedulazione locale persistente per reminder evento/workout.
2. `LocalNotificationService.show` e' solo immediato.
3. Non esistono `schedule/cancel/update` reminder.
4. Non esiste ID reminder stabile derivato da evento/occorrenza/minuti.
5. Non esiste sync reminder su login/restore.
6. Non esiste sync reminder su caricamento calendario.
7. Non esiste cancellazione locale quando un evento viene modificato o eliminato.
8. Non esiste supporto Android a exact alarms o boot reschedule.
9. Il backend push attuale e' Web Push browser, non push nativo FCM/APNs.
10. Il token e' persistito ma non in secure storage.
11. Non esiste refresh token: dopo scadenza JWT il restore porta al logout.

## 7. Rischi probabili

1. Utente crea evento tra un mese con reminder, chiude app, non riceve nulla sull'app Flutter.
2. Utente riapre app dopo giorni: se il token e' scaduto, deve rifare login.
3. In produzione Docker, se `APP_JWT_EXPIRATION_SECONDS` resta default 3600, il login puo durare solo un'ora.
4. Se si aggiungesse scheduling locale senza deduplica, ogni refresh calendario potrebbe duplicare notifiche.
5. Se si aggiungesse scheduling locale senza cancellazione, update/delete evento lascerebbe notifiche vecchie.
6. Se si schedulano molte ricorrenze senza orizzonte, si rischia di saturare pending notifications o allarmi.
7. Cambi timezone/DST possono spostare reminder se non si usa timezone esplicito.

## 8. Fix consigliati, ordinati per priorita

1. Rendere sicuro e testato lo storage token.
   - Passare a `flutter_secure_storage` oppure mantenere MethodChannel ma usare Keystore/Keychain.
   - Aggiungere test `AuthController.restore`.

2. Definire reminder locali nativi senza cambiare API backend.
   - Aggiungere a `LocalNotificationService` metodi `schedule`, `cancel`, `cancelAllForEvent`.
   - Usare `flutter_local_notifications` con `timezone`, oppure implementare AlarmManager/UNCalendarNotificationTrigger nei channel nativi.
   - Usare ID stabile: hash di `eventId`, `eventDate`, `reminderMinutesBefore`.

3. Aggiungere sync reminder dopo auth ready.
   - Dopo restore/login, caricare una finestra futura ragionevole, per esempio 60 o 90 giorni.
   - Schedulare solo eventi con `reminderEnabled`.
   - Non dipendere dallo stato runtime della pagina aperta.

4. Agganciare scheduling a create/update/delete evento.
   - Dopo create/update riuscito, schedulare o aggiornare reminder locali.
   - Dopo delete/hide, cancellare reminder locali collegati all'evento.

5. Gestire ricorrenze per occorrenze concrete.
   - Visto che il backend espande le ricorrenze, schedulare le occorrenze ricevute da `/events`.
   - Definire un orizzonte mobile documentato.

6. Permessi Android.
   - Mantenere `POST_NOTIFICATIONS` e `VIBRATE`.
   - Valutare `SCHEDULE_EXACT_ALARM` solo se si sceglie exact alarm e accettarne le restrizioni Android 12+.
   - Aggiungere boot reschedule se si usa AlarmManager.

7. Separare Web Push da local reminders.
   - Il mobile puo continuare a mostrare stato VAPID come informazione, ma non deve far credere che quello abiliti reminder nativi.

## 9. File da modificare per ogni fix

Storage/auth:

- `pubspec.yaml`
- `lib/core/storage/session_storage.dart`
- `lib/features/auth/auth_controller.dart`
- `lib/main.dart`
- `android/app/src/main/kotlin/com/example/lifeplanner_mobile/MainActivity.kt` se si mantiene MethodChannel
- `ios/Runner/AppDelegate.swift` se si mantiene MethodChannel
- `test/session_storage_test.dart`
- nuovo test auth controller

Reminder locali:

- `pubspec.yaml`
- `lib/core/notifications/local_notification_service.dart`
- nuovo service, per esempio `lib/core/notifications/reminder_scheduler_service.dart`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/example/lifeplanner_mobile/MainActivity.kt` se platform channel custom
- `ios/Runner/AppDelegate.swift` se platform channel custom
- `lib/features/planning/event_form_sheet.dart`
- `lib/features/planning/planning_screens.dart`
- `lib/main.dart` o `AuthController` per sync post-restore
- test per calcolo reminder, ID stabile, deduplica, update/delete

Ricorrenze/reminder future:

- `lib/data/models/planning_models.dart`
- `lib/data/services/planning_api.dart`
- nuovo helper pure Dart per finestre future e due time
- test su evento singolo e ricorrenze ricevute dal backend

## 10. Test manuali consigliati

Auth:

1. Login su Android reale.
2. Chiudere completamente app.
3. Riaprire app e verificare che entri direttamente in `MainShell`.
4. Forzare token scaduto e verificare logout controllato.
5. Avviare app senza rete con sessione cached e verificare comportamento.

Reminder evento singolo:

1. Concedere permesso notifiche.
2. Creare evento domani con reminder 10 minuti.
3. Verificare pending notification o alarm nativo.
4. Modificare orario evento e verificare cancellazione vecchio reminder.
5. Eliminare evento e verificare cancellazione reminder.

Reminder evento tra un mese:

1. Creare evento tra 30 giorni con reminder.
2. Chiudere app.
3. Riaprire app e verificare che il reminder sia ancora pending.
4. Riavviare telefono e verificare che venga ripristinato, se supportato dalla soluzione scelta.

Ricorrenze:

1. Creare evento settimanale per un mese con reminder.
2. Aprire mese/settimana e verificare occorrenze.
3. Verificare che siano schedulate solo occorrenze entro l'orizzonte deciso.
4. Ricaricare calendario piu volte e verificare assenza di duplicati.

Workout:

1. Avviare runner con recupero breve.
2. Verificare notifica e vibrazione foreground a ogni recupero.
3. Completare workout e verificare notifica finale.

Permessi:

1. Android 13+: negare `POST_NOTIFICATIONS` e verificare messaggio chiaro.
2. Android 13+: concedere permesso e riprovare.
3. iOS: concedere e negare permesso notifiche.
