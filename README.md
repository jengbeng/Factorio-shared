# Factorio Shared Sync

Система синхронизации общего сохранения Factorio через GitHub.

## Возможности

- Один общий мир для всех игроков.
- Автоматический выбор: уже есть хост или нужно стать хостом.
- Автоматическое копирование последнего сейва на машину хоста.
- Версии сейвов:
  - `saves/shared.zip` — самое первое сохранение.
  - `saves/shared_YYYY-MM-DDTHH-MM-SSZ.zip` — версии по времени (UTC).
  - `saves/latest.zip` — указатель на последний сейв.
- Автопуш состояния:
  - при запуске хоста — `online = true`,
  - heartbeat раз в 3 минуты,
  - при выходе из игры — новый сейв + `online = false`.
- TTL статуса хоста — 3 минуты 30 секунд (210 сек).

## Структура репозитория

```text
factorio-shared/
 ├─ factorio-sync         # скрипт для macOS (bash)
 ├─ factorio-sync.ps1     # скрипт для Windows (PowerShell)
 ├─ saves/                # сюда складываются версии сейвов
 ├─ meta/
 │   └─ host.json         # состояние хоста (online/offline, last_seen)
 └─ README.md
