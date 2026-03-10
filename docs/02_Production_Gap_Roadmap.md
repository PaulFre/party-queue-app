# Production Gap Roadmap

## Priorisierte Luecken (P0 -> P2)

## P0 Stabilisierung (sofort)

### 1) Runtime-Stabilitaet Web + Session-Flows
- **Problem**: Dev-Start und Browser-Flow muessen reproduzierbar sein.
- **Massnahme**: Smoke-Skript, feste Preflight-Kommandos, Crash-Logs standardisieren.
- **Erfolgskriterium**: 10/10 lokale Startlaeufe ohne Tool/Runtime-Abbruch.

### 2) Test-Baseline und Regression-Schutz
- **Problem**: Einzelne veraltete Tests brechen Gesamtlauf.
- **Massnahme**: Widget-Smoke-Test auf aktuelle App anheben, Realtime-Happy-Path automatisieren.
- **Erfolgskriterium**: `flutter test` und `flutter analyze` dauerhaft gruen.

### 3) Realtime-Domain entkoppeln
- **Problem**: Realtime-Logik schwer ohne Firebase testbar.
- **Massnahme**: Abstraktion via Sync-Interface + In-Memory-Testadapter.
- **Erfolgskriterium**: Realtime-Kernlogik ist offline automatisiert testbar.

## P1 Product-Maturity (naechster Sprint)

### 4) UX-Haertung Join/Fehlerbilder
- **Massnahme**: Klare Fehlermeldungen, Retry-Aktionen, Ladezustand und Success-Feedback.
- **Erfolgskriterium**: Usability-Test ohne unklare Zustandswechsel.

### 5) Telemetrie und Diagnose
- **Massnahme**: Strukturierte Logs fuer Host/Gast-Aktionen und Realtime-Fehler.
- **Erfolgskriterium**: Fehlerursachen in < 5 Minuten nachvollziehbar.

### 6) Daten- und Zugriffsschutz
- **Massnahme**: Firestore Rules, Input-Validation, Abuse-Limits fuer Commands.
- **Erfolgskriterium**: Keine unautorisierten State-Updates in Security-Tests.

## P2 Growth/Scale (nach MVP)

### 7) Echte Spotify-Integration
- **Massnahme**: OAuth, Token-Refresh, echte Suche/Playback.
- **Erfolgskriterium**: End-to-end Musiksteuerung ohne Mock.

### 8) CI/CD und Release-Automatisierung
- **Massnahme**: Pipeline fuer Analyze/Test/Build + Artefakte.
- **Erfolgskriterium**: Jeder Merge triggert automatisches Qualitaets-Gate.

### 9) Multi-Platform Qualitaet
- **Massnahme**: Web, Android, iOS, Windows Smoke-Matrix.
- **Erfolgskriterium**: Release-Kandidat auf allen Zielplattformen verifiziert.

## Umsetzungsvorschlag in Etappen
- **Woche 1**: P0.1 + P0.2 abschliessen.
- **Woche 2**: P0.3 + P1.4 starten.
- **Woche 3**: P1.5 + P1.6 abschliessen.
- **Woche 4+**: P2 sequenziell nach Business-Prioritaet.
