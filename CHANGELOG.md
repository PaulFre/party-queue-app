# Changelog

## [2026-03-11]

### Added
- Realtime-Protokoll-Hardening mit strikter Command-Payload-Validierung pro Command-Typ.
- Replay-/Stale-Schutz fuer Realtime-Commands inkl. dedizierter Fehlercodes.
- Strukturierte Telemetrie-Events (`recentTelemetry`) fuer Realtime- und Join-Flows.
- Neue Tests:
  - Realtime Protocol Hardening
  - Join-Flow State und Retry-UX
  - In-memory Realtime Sync Support Utilities

### Changed
- Party-Engine modularisiert in:
  - `QueuePolicyService`
  - `RealtimeCoordinator` + `RealtimeCommandContract`
  - `SessionService`
- Join-Flow-UX auf explizite Zustandsmaschine umgestellt (Access/Profile + Async-State).
- Einheitliches Error-Mapping fuer Join-Fehler inkl. Retry-CTA.

### Fixed
- CI/Workflow-Fehler rund um `CODECOV_TOKEN`-Kontextberechtigungen bereinigt.
- Realtime-Command-Ack- und Fehlerbehandlung konsolidiert.
- Session-Rejoin-Handling auf robustere Snapshot-Logik umgestellt.

### Security
- Firestore Security Rules Test-Job in CI etabliert.
- Branch-Protection um `CI / Firestore Security Rules` als Pflicht-Check erweitert.
