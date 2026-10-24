# Bild zu Text

- Bild aus der Zwischenablage → Klick aufs Icon → Text kopiert
- Lokal · Apple Vision · Deutsch / Englisch
- Rechtsklick: Schließen

## Installation

- [DMG herunterladen](https://github.com/theophieln/bild-zu-text/releases/latest) · Apple Silicon · macOS 13+
- App nach Programme ziehen
- Nicht notarisiert · Falls blockiert: Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen

## Bauen

- Apple Command Line Tools · Swift 6

```sh
./build.sh
./test.sh
./release.sh
```

- App: `build/Bild zu Text.app` · DMG: `dist/Bild-zu-Text.dmg`
- [MIT](LICENSE)
