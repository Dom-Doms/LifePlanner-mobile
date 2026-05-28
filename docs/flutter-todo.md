# Flutter TODO

Questa app usa solo endpoint gia presenti nel backend LifePlanner e platform channel nativi locali.

## Auth mobile

- La sessione mobile usa `flutter_secure_storage` tramite `SessionStorage`: access token, refresh token e user JSON non vengono piu salvati nel vecchio MethodChannel SharedPreferences/UserDefaults.
- Al primo avvio dopo update, se secure storage e vuoto ma esiste una sessione legacy, l'app migra `token` e `user` in secure storage e cancella la sessione legacy. Le sessioni legacy non contengono `refreshToken`: restano valide solo finche il vecchio access token non scade; dopo un nuovo login viene salvato anche il refresh token.
- `ApiClient` ritenta una sola volta le richieste autenticate dopo un 401 se il refresh token e valido. Se il refresh fallisce, `AuthController.logout` pulisce la sessione locale.

## Da completare quando ci sono decisioni o endpoint dedicati

- Push remoto nativo: Android usa FCM tramite `MobilePushService` e registra token su `/mobile/device-tokens` dopo login/restore. Serve configurare `android/app/google-services.json` e backend `MOBILE_PUSH_ENABLED=true` con `FIREBASE_CREDENTIALS_PATH`. iOS/APNs resta TODO.
- Reminder locali schedulati: il platform channel attuale espone notifiche immediate e vibrazione per workout foreground. La programmazione locale persistente degli eventi a app chiusa richiede un alarm scheduler nativo dedicato oppure un plugin di scheduling, senza nuovi endpoint.
- Deep link reset password: la schermata esiste, ma serve decidere schema nativo o Universal/App Links per aprire automaticamente `/reset-password?token=...` dalle email.
- Timer workout in background affidabile: Android usa `WorkoutForegroundService`; iOS richiede ancora local notifications + resume reconciliation.
- iOS runner background: Android usa un foreground service nativo per il countdown live. iOS non ha un equivalente diretto sicuro per timer arbitrari in background; servono local notifications per lo step corrente + resume reconciliation, da progettare separatamente senza simulare un foreground service finto.
- Offline mode: la PWA attuale usa API `NetworkOnly`; qui non e stata introdotta cache offline business per non inventare logiche nuove.
- Amministrazione utenti: il backend ha endpoint admin, ma la spec non documenta schermate frontend equivalenti.
- Subscription Web Push: gli endpoint `/push/subscriptions` accettano subscription browser, non una subscription nativa Flutter compatibile.
- Tap reminder FCM: apre l'app ma non naviga ancora direttamente alla giornata/evento.

## Parzialmente implementato

- Editor workout: supporta step top-level, recuperi, gruppi, step nei gruppi, riordino top-level e salvataggio payload `steps`/`blocks`. Mantiene gli esercizi legacy gia presenti durante l'edit per non perdere compatibilita.
- Eventi: supporta create/update/delete, ricorrenza, promemoria, partecipanti free-text/registered e template workout. La UX e mobile nativa essenziale, non una copia pixel-perfect della modale Vue.
