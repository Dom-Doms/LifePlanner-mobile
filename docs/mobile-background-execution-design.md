# Mobile background execution design

Analisi tecnica su runner workout e reminder calendario/eventi.

Scope: solo analisi. Nessuna modifica a Flutter, Android, iOS o backend.

## File analizzati

Flutter:

- `lib/features/workout/workout_runner_controller.dart`
- `lib/features/workout/workout_screens.dart`
- `lib/core/notifications/local_notification_service.dart`
- `android/app/src/main/kotlin/com/example/lifeplanner_mobile/MainActivity.kt`
- `ios/Runner/AppDelegate.swift`
- `lib/data/services/planning_api.dart`
- `lib/data/services/push_api.dart`
- `lib/features/planning/event_form_logic.dart`
- `lib/features/auth/auth_controller.dart`
- `pubspec.yaml`

Backend:

- `LifePlanner/src/main/java/it/univ/lifeplanner/push/service/ReminderScheduler.java`
- `LifePlanner/src/main/java/it/univ/lifeplanner/push/service/PushNotificationService.java`
- `LifePlanner/src/main/java/it/univ/lifeplanner/push/dto/PushSubscriptionRequest.java`
- `LifePlanner/src/main/java/it/univ/lifeplanner/planning/dto/CalendarEventRequest.java`
- `LifePlanner/src/main/java/it/univ/lifeplanner/security/JwtTokenService.java`
- `LifePlanner/src/main/resources/application.yml`

## 1. Stato attuale runner Flutter

### Dove vive il timer

Il timer del runner vive in `WorkoutRunnerController`.

Il controller:

- mantiene `Timer? _timer`;
- inizializza il timer nel costruttore con `_startTimer()` se la run non è finita;
- usa `Timer.periodic(const Duration(seconds: 1), ...)`;
- ad ogni tick incrementa `elapsedSeconds`;
- riduce `remainingTime` per step temporizzati;
- quando `remainingTime <= 0`, chiama `onTimedStepComplete` e passa allo step successivo.

La schermata `WorkoutRunScreen` crea il controller dopo `getWorkoutRun(runId)` e registra callback per notifiche immediate di fine step e fine workout.

### Cosa succede su `AppLifecycleState.paused/inactive/detached`

Nel codice Flutter attuale non risulta registrato nessun `WidgetsBindingObserver`, nessun `didChangeAppLifecycleState` e nessuna gestione esplicita di:

- `AppLifecycleState.inactive`;
- `AppLifecycleState.paused`;
- `AppLifecycleState.detached`;
- `AppLifecycleState.resumed`.

Quindi il runner non riceve un evento applicativo per salvare uno snapshot nel momento in cui l'app entra in background, né per riconciliare il tempo al ritorno in foreground.

### Se salva snapshot quando va in background

Non in modo esplicito.

La schermata salva lo stato in tre casi:

- `dispose()` chiama `_persistState()`;
- un autosave periodico ogni 15 secondi chiama `_persistState()`;
- alcune azioni utente, come pausa, step precedente, step completato e reorder, chiamano `_persistState()`.

Questo non equivale a un salvataggio affidabile su background:

- `dispose()` non è garantito quando il telefono viene bloccato;
- il `Timer.periodic` di autosave è anch'esso Dart foreground e può essere sospeso;
- non esiste hook lifecycle che salvi immediatamente su `paused` o `inactive`.

### Se al resume ricalcola il tempo passato

No.

Il controller idrata da backend leggendo:

- `elapsedSeconds`;
- `currentStepIndex`;
- `status`;
- `remainingTime` da `snapshotJson`.

Non salva un timestamp locale tipo `lastTickAt`, `backgroundedAt` o `lastSnapshotAt`, e non applica una differenza tra ora corrente e ultimo tick quando l'app torna in foreground.

Questo significa che, se il telefono rimane bloccato per 90 secondi, il runner non scala automaticamente quei 90 secondi da `remainingTime` al resume.

### Perché il timer si blocca a schermo bloccato

Perché il runner dipende da `Timer.periodic` dentro l'isolato Dart dell'app Flutter. Quando Android mette l'app in background, sospende o limita l'esecuzione dell'isolato Dart. Con schermo bloccato l'app non ha un meccanismo nativo che garantisca esecuzione continua.

Le notifiche attuali non risolvono questo punto:

- `LocalNotificationService.show(...)` invoca una notifica immediata via MethodChannel;
- Android `MainActivity.showNotification(...)` fa solo `manager.notify(...)`;
- iOS crea una `UNNotificationRequest` con `trigger: nil`, quindi immediata;
- non esistono scheduler futuri, alarm nativi o foreground service;
- `pubspec.yaml` non include plugin come `flutter_local_notifications`, `workmanager`, `android_alarm_manager_plus`, `firebase_messaging` o plugin foreground service.

Diagnosi: il comportamento osservato su Android reale è coerente con l'architettura attuale.

## 2. Soluzioni possibili per runner

### Solo foreground timer + resume reconciliation

Idea:

- mantenere `Timer.periodic` quando l'app è aperta;
- salvare timestamp e snapshot su `paused/inactive`;
- al `resumed`, calcolare il delta reale da `DateTime.now()` e avanzare la macchina a stati;
- persistere subito lo stato riconciliato.

Affidabilità con schermo bloccato:

- media per correttezza dello stato al ritorno;
- bassa per avvisi esatti durante lo schermo bloccato, perché il tick non continua in tempo reale.

Complessità Flutter:

- bassa/media;
- richiede `WidgetsBindingObserver`, timestamp nello snapshot e funzione deterministica per avanzare più secondi in blocco.

Complessità Android/iOS:

- bassa;
- nessuna esecuzione nativa continua.

Impatto UX:

- al ritorno l'utente vede il tempo corretto;
- durante il blocco potrebbe non ricevere cue intermedi puntuali.

Limiti:

- non garantisce vibrazione/notifica esattamente a fine step mentre lo schermo è bloccato;
- non è adatta se il runner deve guidare l'allenamento senza riaprire l'app.

### Local notifications schedulate per fine step/recupero

Idea:

- quando parte uno step temporizzato, schedulare una notifica locale per la fine dello step;
- cancellare/reschedulare in caso di pausa, resume, step manuale, reorder o fine workout.

Affidabilità con schermo bloccato:

- media su Android se implementata con scheduler/allarme adeguato;
- media su iOS per notifiche locali, ma con limiti di quantità e controllo del sistema;
- non mantiene il timer vivo, consegna solo cue.

Complessità Flutter:

- media;
- serve introdurre uno scheduler, gestione cancel/update e mapping stabile degli ID notifica.

Complessità Android/iOS:

- media;
- Android richiede attenzione a exact alarms, Doze, permessi e boot reschedule se si vogliono notifiche persistenti;
- iOS usa `UNCalendarNotificationTrigger` o `UNTimeIntervalNotificationTrigger`, con limiti sul numero di pending notifications.

Impatto UX:

- l'utente riceve un avviso anche a schermo bloccato;
- toccando la notifica deve tornare al runner, che comunque deve riconciliare lo stato.

Limiti:

- non sostituisce una state machine robusta;
- i reorder o le pause devono cancellare notifiche vecchie per evitare cue sbagliati;
- non è ideale per sequenze molto lunghe se si schedulano tutti gli step in anticipo.

### Android foreground service

Idea:

- spostare la parte critica del runner Android in un foreground service con notifica persistente;
- mantenere tempo corrente, step corrente e countdown anche a schermo bloccato;
- comunicare con Flutter quando l'app è visibile;
- persistere snapshot periodici o su transizioni importanti.

Affidabilità con schermo bloccato:

- alta su Android se il servizio è avviato correttamente come foreground service e mostra notifica persistente;
- è la soluzione Android più adatta per un timer workout live.

Complessità Flutter:

- media/alta;
- Flutter deve orchestrare start/stop/pause/resume e ricevere stato dal servizio.

Complessità Android/iOS:

- alta su Android;
- richiede service nativo o plugin dedicato, manifest, permessi foreground service, canali notifica e gestione Android 12+ / 13+ / 14+;
- non è portabile direttamente su iOS.

Impatto UX:

- notifica persistente durante workout;
- comportamento atteso per timer attivi tipo fitness/timer;
- maggiore consumo batteria rispetto al solo foreground timer.

Limiti:

- Android-only;
- va progettato con attenzione per evitare stato divergente tra servizio, Flutter e backend;
- richiede policy e permessi corretti.

### Eventuale background task iOS

Idea:

- valutare strumenti iOS come background modes, `BGTaskScheduler` o audio/background processing.

Affidabilità con schermo bloccato:

- bassa per un countdown continuo arbitrario;
- iOS non consente normalmente timer continuativi in background per app non appartenenti a categorie specifiche.

Complessità Flutter:

- media/alta.

Complessità Android/iOS:

- alta su iOS, con molti vincoli di piattaforma e revisione App Store.

Impatto UX:

- possibile supporto parziale;
- più realistico affidarsi a notifiche locali e resume reconciliation.

Limiti:

- non considerarla equivalente al foreground service Android;
- per iOS il design robusto deve essere "notifica locale + riconciliazione al ritorno", salvo requisiti specifici molto forti.

## 3. Soluzione consigliata per runner

### Minimo immediato

Implementare resume reconciliation.

Step tecnici:

- aggiungere osservazione lifecycle nella schermata o in un controller dedicato;
- su `inactive/paused`, salvare snapshot con timestamp reale;
- su `resumed`, ricaricare o riconciliare lo snapshot locale;
- avanzare la state machine in base ai secondi realmente trascorsi;
- persistere lo stato corretto sul backend;
- mantenere `Timer.periodic` solo per l'esperienza foreground.

Questo risolve la diagnosi principale: il timer non deve dipendere dal numero di tick ricevuti mentre l'app è sospesa.

### Soluzione robusta Android

Implementare un foreground service Android per il runner.

Strategia:

- il runner Flutter resta UI e orchestratore;
- Android foreground service diventa proprietario del countdown attivo quando il workout è in corso;
- il service mostra notifica persistente con step corrente e tempo residuo;
- azioni notifica minime: pausa/riprendi, stop, apri app;
- lo stato viene serializzato in snapshot compatibile con il backend;
- Flutter al resume legge lo stato dal service o dal backend e aggiorna UI.

Questa è la soluzione corretta se il requisito è: "il workout deve continuare e avvisare anche a telefono bloccato".

### TODO iOS

Per iOS non pianificare una copia 1:1 del foreground service Android.

TODO consigliato:

- implementare resume reconciliation anche su iOS;
- aggiungere notifiche locali schedulate per fine step corrente;
- valutare solo dopo test reali se servono background modes specifici;
- documentare i limiti iOS come comportamento di piattaforma, non come bug Flutter.

## 4. Stato attuale reminder eventi

### Flutter schedula notifiche future?

No, nel checkout corrente Flutter non schedula notifiche future per eventi calendario.

Evidenze:

- `LocalNotificationService` espone `requestPermission`, `areNotificationsEnabled`, `show` e vibrazione;
- Android gestisce solo `show` immediato e `vibrate`;
- iOS crea notifiche con `trigger: nil`, quindi immediate;
- `PlanningApi` invia al backend gli eventi con `reminderEnabled` e `reminderMinutesBefore`;
- non esiste un service Flutter dedicato a pending notification, local schedule, cancel o reschedule;
- `PushApi` espone solo VAPID public key e test notification, non registra token nativi.

### Backend oggi fa Web Push PWA?

Sì.

Il backend ha:

- `PushSubscriptionRequest` con `endpoint`, `p256dh`, `auth`, cioè formato Web Push browser/service worker;
- configurazione VAPID in `application.yml`;
- `PushNotificationService` che usa `nl.martijndwars.webpush.Notification` e `PushService`;
- `ReminderScheduler` schedulato ogni 60 secondi che cerca eventi con reminder dovuti e invia push agli utenti destinatari.

Questo è Web Push, adatto alla PWA/browser, non push nativo mobile.

### Manca FCM/APNs per mobile nativo?

Sì.

Nel backend non risultano classi, DTO o configurazioni per:

- device token Android/iOS;
- Firebase Cloud Messaging;
- APNs;
- endpoint di registrazione token mobile;
- tabella device installation;
- refresh/rotazione token push nativi.

Nel Flutter non risulta `firebase_messaging` o altra integrazione FCM/APNs.

## 5. Soluzione consigliata per reminder calendario

### Local scheduled notifications Flutter

Idea:

- quando l'app scarica o modifica eventi, schedula local notifications per i prossimi reminder;
- cancella/reschedula quando cambia un evento;
- gestisce ricorrenze con orizzonte limitato.

Pro:

- può funzionare anche offline dopo scheduling;
- non richiede subito backend FCM/APNs;
- utile come fallback locale.

Contro:

- dipende dall'app che abbia già aperto e schedulato gli eventi futuri;
- se un evento viene creato da web o altro device, il mobile non lo sa finché non sincronizza;
- su Android servono exact alarm/boot reschedule per affidabilità alta;
- su iOS ci sono limiti sul numero di pending notifications;
- ricorrenze lunghe dopo giorni/settimane richiedono rolling window.

Diagnosi: utile come fallback, non come architettura primaria multi-device.

### Backend push nativo FCM/APNs

Idea:

- il backend mantiene device token mobile per utente;
- `ReminderScheduler` invia reminder via provider nativo;
- Android riceve via FCM;
- iOS riceve via APNs, direttamente o tramite FCM;
- Web Push resta per PWA.

Pro:

- funziona anche se app chiusa da giorni o settimane;
- il backend è fonte unica per reminder, ricorrenze, partecipanti e aggiornamenti cross-device;
- evita dipendenza dall'ultimo sync locale del telefono;
- si integra meglio con calendario condiviso e notifiche inviate a partecipanti.

Contro:

- richiede nuovo sottosistema backend;
- richiede gestione token, revoca, retry, errori provider e ambienti prod/dev;
- richiede setup Firebase/APNs e configurazione sicura.

Diagnosi: è la soluzione corretta per reminder calendario affidabili con app chiusa.

### Approccio ibrido

Idea:

- backend FCM/APNs come canale primario;
- local scheduled notifications come fallback o ottimizzazione per eventi già sincronizzati;
- Web Push resta canale PWA.

Pro:

- copre il caso app chiusa da giorni/settimane;
- offre fallback locale quando il device ha già dati;
- mantiene separazione tra PWA e mobile nativo.

Contro:

- richiede deduplica tra notifica backend e notifica locale;
- serve una strategia di ID notification e `collapseKey/threadIdentifier`;
- maggiore complessità di test.

Diagnosi: consigliato come target finale, ma dopo avere introdotto il push nativo backend.

## 6. Architettura consigliata finale

### Runner workout

Responsabilità:

- runner workout = foreground service Android + resume reconciliation;
- Flutter UI = rendering, comandi utente, stato visibile;
- backend = snapshot persistente e stato run, non timer in tempo reale;
- notifiche step = generate dal foreground service Android o local schedule per iOS/fallback.

Regola:

```text
Workout live Android: Flutter UI -> Android foreground service -> snapshot -> backend
Workout live iOS: Flutter UI -> local notification corrente + resume reconciliation -> backend
```

### Reminder calendario

Responsabilità:

- reminder calendario = backend FCM/APNs;
- Web Push esistente = canale PWA/browser;
- local scheduled notifications = fallback mobile opzionale, non fonte primaria.

Regola:

```text
Evento salvato -> backend calcola reminder dovuti -> Web Push per PWA + FCM/APNs per mobile nativo
```

### Login persistence

Login persistence è un problema separato.

Nel checkout attuale:

- Flutter persiste token e user in `SessionStorage`;
- al restore chiama `/auth/me`;
- se riceve 401/403 fa logout;
- il backend genera JWT con `app.jwt.expiration-seconds`, default 86400 secondi.

Quindi la persistenza login non deve essere confusa con background execution:

- runner fermo a schermo bloccato = problema di lifecycle/timer;
- reminder mancanti dopo giorni/settimane = problema di push nativo/scheduling;
- logout dopo tempo = problema di durata JWT e refresh token.

## 7. Piano implementativo

### A. Fix minimo runner background/resume

Obiettivo: il timer mostra stato corretto dopo blocco/sblocco anche senza servizio nativo.

Step:

1. Aggiungere gestione lifecycle al runner.
2. Salvare `lastSnapshotAt` o `lastTickAt` nello snapshot.
3. Su `paused/inactive`, persistere subito lo stato.
4. Su `resumed`, calcolare secondi trascorsi e avanzare gli step temporizzati.
5. Gestire più step scaduti nello stesso delta.
6. Persistere lo stato riconciliato.
7. Testare con unit test su avanzamento multi-secondo e transizione step.

### B. Foreground service Android per runner

Obiettivo: countdown affidabile con telefono bloccato.

Step:

1. Scegliere plugin o implementazione nativa Kotlin.
2. Aggiungere foreground service Android e permessi necessari.
3. Spostare il countdown attivo nel service per Android.
4. Notifica persistente con step corrente e tempo residuo.
5. Azioni notifica: pausa/riprendi, stop, apri app.
6. Sync service -> Flutter quando l'app è visibile.
7. Snapshot periodico o su transizioni step.
8. Test su Android reale con schermo bloccato, Doze leggero e app in background.

### C. Backend FCM/APNs per reminder eventi

Obiettivo: reminder calendario affidabili anche con app chiusa dopo giorni/settimane.

Step:

1. Aggiungere modello device installation/token nativo.
2. Endpoint mobile per registrare/aggiornare/rimuovere token.
3. Integrare FCM per Android.
4. Decidere APNs diretto o APNs via FCM per iOS.
5. Estendere `ReminderScheduler` per inviare anche push nativi.
6. Gestire token scaduti o invalidi.
7. Mantenere Web Push PWA esistente.
8. Aggiungere test service su selezione destinatari e dispatch canali.

### D. Eventuale local scheduled fallback

Obiettivo: fallback locale per eventi già sincronizzati sul device.

Step:

1. Aggiungere scheduler locale mobile.
2. Schedulare solo una finestra futura limitata.
3. Cancellare/reschedulare su modifica evento.
4. Deduplicare con push backend usando ID evento/reminder.
5. Android: valutare exact alarms e boot reschedule.
6. iOS: rispettare limiti pending notification.

### E. Refresh token/session hardening

Obiettivo: rendere la sessione mobile indipendente dalla durata breve del JWT.

Step:

1. Introdurre refresh token backend.
2. Salvare refresh token in storage sicuro.
3. Rinnovare access token prima della scadenza o su 401 recuperabile.
4. Gestire revoca/logout.
5. Separare chiaramente errori auth da errori background/notification.

## Diagnosi finale

Il runner si blocca perché oggi è un timer Dart foreground. L'autosave ogni 15 secondi e le notifiche immediate non garantiscono esecuzione quando Android sospende l'app a schermo bloccato.

I reminder calendario non devono dipendere dall'app Flutter aperta. Il backend oggi supporta reminder tramite Web Push PWA, ma non ha push nativo FCM/APNs. Per notifiche dopo giorni/settimane con app chiusa, la soluzione primaria deve essere backend push nativo.

## Ordine dei fix consigliato

1. Fix minimo runner con lifecycle snapshot + resume reconciliation.
2. Foreground service Android per runner live affidabile.
3. Backend FCM/APNs per reminder calendario.
4. Local scheduled notifications come fallback, con deduplica.
5. Refresh token/session hardening come tema separato.
