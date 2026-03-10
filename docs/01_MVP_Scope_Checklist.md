# MVP Scope Checklist

## Zielbild
Ein stabiler Party-Flow fuer Host und Gast mit Live-Queue, Voting und optionalem Firebase-Realtime-Betrieb.

## Must-Have Scope (Release-Blocker)

### 1) Einstieg und Session
- Landing-Flow mit Host- und Gast-Einstieg vorhanden.
- Host kann Raum erstellen.
- Gast kann Raum beitreten.
- Session-Reconnect (smart rejoin) funktioniert.

**Abnahme**
- Host erstellt Raum in < 30 Sekunden.
- Gast tritt mit gueltigem Zugang bei.
- Nach App-Neustart kann letzte Session wieder aufgenommen werden.

### 2) Queue- und Voting-Core
- Song-Add fuer Host und Gast.
- Like/Dislike je User pro Song.
- Deterministische Sortierung.
- Duplicate- und Cooldown-Regeln aktiv.

**Abnahme**
- Mehrfaches Tappen auf denselben Vote toggelt korrekt.
- Derselbe Song kann nicht doppelt in aktive Queue gelangen.
- Nach Cooldown-Ablauf ist Song wieder addbar.

### 3) Host-Steuerung
- Skip/Pin/Remove verfuegbar.
- Voting pausierbar.
- Host-only-adds und Room-Lock verfuegbar.

**Abnahme**
- Host-Aktionen wirken sofort im Raumzustand.
- Gast kann gesperrte Aktionen nicht ausfuehren.

### 4) Realtime-Betrieb
- Host publiziert autoritativen Raumzustand.
- Gast schickt Commands an Host.
- Alle Clients abonnieren Room-Snapshots.

**Abnahme**
- Host + mindestens ein Gast bleiben synchron.
- Gast-Add und Gast-Vote erscheinen auf Host-Seite.
- Fehlerfall setzt nachvollziehbare Fehlermeldung (`lastSyncError`).

### 5) Test- und Build-Basis
- `flutter analyze` ohne Fehler.
- `flutter test` ohne Fehler.
- `flutter build web` erfolgreich.

**Abnahme**
- Alle drei Kommandos laufen lokal reproduzierbar gruen.

## Out of Scope fuer MVP
- Echte Spotify OAuth/Web API Integration (derzeit Mock).
- Billing, Multi-Tenant-Admin, Observability-Stack.
- Vollstaendige Security-Hardening-Massnahmen fuer Production.

## Go/No-Go Release Gate
- Scope-Punkte 1-5 sind bestanden.
- Keine kritischen Abstuerze in Host/Gast-Happy-Path.
- Dokumentierte bekannte Rest-Risiken sind akzeptiert.
