# Flutter TODO

Questa app usa solo endpoint gia presenti nel backend LifePlanner e platform channel nativi locali.

## Da completare quando ci sono decisioni o endpoint dedicati

- Push remoto nativo: il backend espone Web Push VAPID per PWA, non token FCM/APNs. L'app Flutter implementa notifiche native locali per il workout, ma non puo ricevere reminder server-side a app chiusa senza estensione backend.
- Deep link reset password: la schermata esiste, ma serve decidere schema nativo o Universal/App Links per aprire automaticamente `/reset-password?token=...` dalle email.
- Timer workout in background affidabile: il runner mantiene timer foreground e salva snapshot sul backend. Foreground service Android/background task iOS richiedono una decisione tecnica separata.
- Offline mode: la PWA attuale usa API `NetworkOnly`; qui non e stata introdotta cache offline business per non inventare logiche nuove.
- Amministrazione utenti: il backend ha endpoint admin, ma la spec non documenta schermate frontend equivalenti.
- Subscription Web Push: gli endpoint `/push/subscriptions` accettano subscription browser, non una subscription nativa Flutter compatibile.

## Parzialmente implementato

- Editor workout: supporta step top-level, recuperi, gruppi, step nei gruppi, riordino top-level e salvataggio payload `steps`/`blocks`. Mantiene gli esercizi legacy gia presenti durante l'edit per non perdere compatibilita.
- Eventi: supporta create/update/delete, ricorrenza, promemoria, partecipanti free-text/registered e template workout. La UX e mobile nativa essenziale, non una copia pixel-perfect della modale Vue.
