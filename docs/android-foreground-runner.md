# Android foreground runner

Il runner workout usa un foreground service Android nativo per mantenere il countdown attivo quando lo schermo viene bloccato o l'app passa in background.

## Architettura

- Flutter resta proprietario della UI, del caricamento run, dello snapshot backend e del completamento via API.
- `WorkoutForegroundService` gestisce solo lo stato live locale: step corrente, `elapsedSeconds`, `remainingTime`, pausa, resume, avanzamento e notifica persistente.
- Il service non riceve token auth e non chiama il backend.
- Quando Flutter e visibile, riceve eventi dal service tramite MethodChannel e aggiorna `WorkoutRunnerController`.
- Quando Flutter torna foreground, chiama `getWorkoutServiceState()` e persiste lo snapshot backend.

## Canali e permessi

MethodChannel:

- `lifeplanner_mobile/workout_foreground_service`

Comandi:

- `startWorkoutService`
- `updateWorkoutService`
- `pauseWorkoutService`
- `resumeWorkoutService`
- `completeCurrentStepWorkoutService`
- `skipWorkoutServiceStep`
- `previousWorkoutServiceStep`
- `stopWorkoutService`
- `getWorkoutServiceState`

Permessi Android:

- `android.permission.FOREGROUND_SERVICE`
- `android.permission.FOREGROUND_SERVICE_DATA_SYNC`
- `android.permission.POST_NOTIFICATIONS`
- `android.permission.VIBRATE`

Canale notifica:

- id: `lifeplanner_workout_foreground`
- nome: `LifePlanner Workout`

## Stato runner

Flutter invia al service una sequenza gia calcolata e gia riordinata. Il service non riflatta il template e non cambia il contratto API.

Step a tempo e recuperi:

- countdown nel service;
- a zero vibrazione nativa breve;
- avanzamento allo step successivo;
- notifica persistente aggiornata.

Step a ripetizioni:

- non avanzano automaticamente;
- aspettano comando da app o azione notifica `Completato`.

Pausa:

- blocca il countdown;
- mantiene `remainingTime`.

Fine/stop:

- rimuove la notifica persistente;
- Flutter completa o cancella usando le API gia esistenti.

## Snapshot backend

Il service non salva sul backend. Flutter salva snapshot:

- su pausa/resume;
- su cambio step quando l'app riceve evento service;
- su ritorno foreground;
- con autosave esistente ogni 15 secondi quando la schermata e attiva;
- su stop/fine.

## iOS

iOS mantiene il comportamento attuale. Non e implementato un foreground service finto. La soluzione futura corretta e local notifications per lo step corrente + resume reconciliation.

## Test manuali consigliati

1. Avvia un workout con recupero breve.
2. Verifica la notifica persistente `LifePlanner workout in corso`.
3. Blocca il telefono.
4. Aspetta la fine del recupero.
5. Verifica vibrazione e avanzamento step.
6. Riapri l'app e verifica step, `remainingTime` ed `elapsedSeconds`.
7. Pausa e riprendi dall'app.
8. Usa stop/fine e verifica rimozione notifica.
9. Riordina uno step futuro durante la run.
10. Blocca il telefono e verifica che l'ordine custom venga rispettato.

## Differenza dai reminder calendario

Il foreground service riguarda solo il runner live. I reminder calendario dopo giorni/settimane restano un problema diverso: richiedono push nativo backend FCM/APNs o local scheduled notifications dedicate.
