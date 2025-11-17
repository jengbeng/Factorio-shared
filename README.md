# Factorio Shared Sync

Система синхронизации общего сохранения **Factorio** через GitHub.  
Идея: у всех игроков один общий мир, который живёт в репозитории.  
Хост нажал кнопку — мир подтянулся, сыграли, закрыли игру — сейв и статус сами улетели в GitHub и стали доступны остальным.

Поддерживаются **macOS** и **Windows**.

---

## Возможности

- Один общий мир для всей компании.
- Автоматический выбор роли:
  - уже есть живой хост → скрипт говорит «просто подключайся»;
  - хоста нет → скрипт предлагает «стать хостом».
- Автоматическое копирование последнего сейва из репозитория на машину хоста.
- Версионирование сейвов:
  - `saves/shared.zip` — самое первое сохранение;
  - `saves/shared_YYYY-MM-DDTHH-MM-SSZ.zip` — последующие версии (UTC);
  - `saves/latest.zip` — указатель на последний сейв, с которым будет играть следующий хост.
- Авто-пуш состояния:
  - при запуске хоста — `online = true`;
  - heartbeat раз в 3 минуты (обновление `last_seen`);
  - при завершении игры — новый сейв + `online = false`.
- TTL статуса хоста — **3 минуты 30 секунд** (210 секунд):
  - если `last_seen` старше — считаем, что хоста нет.
- Интерактивный режим:
  - просто `./factorio-sync` или `.actorio-sync.ps1` → скрипт покажет состояние и предложит действия (для людей, а не для админов).

---

## Как это работает (коротко)

Репозиторий содержит:

```text
factorio-shared/
 ├─ factorio-sync         # скрипт для macOS (bash)
 ├─ factorio-sync.ps1     # скрипт для Windows (PowerShell)
 ├─ saves/
 │   ├─ shared.zip                      # самое первое сохранение
 │   ├─ shared_YYYY-MM-DDTHH-MM-SSZ.zip # последующие версии
 │   └─ latest.zip                      # последний сейв для старта
 └─ meta/
     └─ host.json       # состояние хоста (online/offline, кто, когда)
```

Когда кто-то становится хостом:

1. Скрипт делает `git pull` и проверяет `meta/host.json`.
2. Если есть живой хост по TTL → показывает, к кому подключаться.
3. Если хоста нет:
   - копирует `saves/latest.zip` в локальную папку Factorio (`shared.zip`);
   - помечает себя как `online = true` и пушит в GitHub;
   - на macOS запускает Factorio и следит за процессом;
   - по закрытию игры — копирует свежий сейв обратно в `saves/`, создаёт новую версию и пушит `online = false`.

Клиенты перед заходом смотрят `host.json` и знают, есть ли актуальный хост.

---

## Требования

### Общие

- Репозиторий на GitHub (общий для всех игроков).
- Доступ **Write** для всех участников:
  - каждый игрок добавлен как Collaborator с правами **Write**,
  - иначе он не сможет пушить сейв и статус.

### macOS

- Git (обычно уже установлен или через Xcode Command Line Tools).
- Factorio (Steam или standalone).
- Терминал (Terminal, iTerm и т.п.).

### Windows

- [Git for Windows](https://git-scm.com/download/win).
- PowerShell (подходит встроенный, лучше PowerShell 7).
- Factorio.
- Разрешён запуск локальных скриптов:

  ```powershell
  Set-ExecutionPolicy RemoteSigned
  ```

---

## Путь к сейвам Factorio

- **macOS**  
  По умолчанию скрипт ожидает сейвы здесь:

  ```text
  ~/Library/Application Support/factorio/saves
  ```

- **Windows**

  ```text
  %APPDATA%\Factorio\saves
  ```
  Обычно это что-то вроде:
  `C:\Users\USERNAME\AppData\Roaming\Factorio\saves`.

При желании можно переопределить переменной окружения `FACTORIO_SAVES_DIR`.

---

## Настройка GitHub и репозитория

### 1. Создать репозиторий на GitHub

1. На GitHub → **New repository**.
2. Название: например, `factorio-shared`.
3. Visibility: `Public` (или `Private` — как хотите).
4. Создать.

Запомнить URL, например:

```text
https://github.com/USER/factorio-shared.git
```

### 2. Привязать локальный репозиторий (первый игрок)

На macOS (аналогично на Windows через Git Bash / PowerShell):

```bash
cd ~/factorio-shared      # или любая другая папка с проектом
git init                  # если ещё не инициализировано
git remote add origin https://github.com/USER/factorio-shared.git
git add .
git commit -m "initial setup"
git branch -M main
git push -u origin main
```

Дальше остальные игроки просто делают:

```bash
git clone https://github.com/USER/factorio-shared.git
```

---

## Установка и первый запуск на macOS

### 1. Клонировать репозиторий

```bash
cd ~
git clone https://github.com/USER/factorio-shared.git
cd factorio-shared
```

### 2. Сделать скрипт исполняемым

```bash
chmod +x factorio-sync
```

### 3. Первичная настройка

```bash
./factorio-sync init
```

Скрипт:

- создаст папки `saves` и `meta`, если их нет;
- предложит настроить `origin`, если он ещё не задан;
- подскажет, как сделать первый коммит.

### 4. Интерактивный запуск

```bash
./factorio-sync
```

Скрипт:

- сделает `git pull`;
- покажет состояние `host.json` (кто, онлайн или нет, когда был);
- предложит варианты (стать хостом / подключиться / пушнуть сейв).

---

## Установка и первый запуск на Windows

### 1. Установить Git и разрешить скрипты PowerShell

1. Установить Git for Windows.
2. Открыть PowerShell **от имени администратора** и выполнить:

   ```powershell
   Set-ExecutionPolicy RemoteSigned
   ```

### 2. Клонировать репозиторий

```powershell
cd C:\Users\USERNAME
git clone https://github.com/USER/factorio-shared.git
cd factorio-shared
```

### 3. Первичная настройка

```powershell
.actorio-sync.ps1 init
```

Скрипт:

- создаст папки `saves` и `meta`;
- проверит наличие `.git` и `origin`;
- подскажет, что делать дальше.

### 4. Интерактивный запуск

```powershell
.actorio-sync.ps1
```

---

## Как играть

### Хост (максимально простой сценарий)

#### macOS

```bash
cd ~/factorio-shared
./factorio-sync
```

В интерактивном меню:

- если хоста нет → появится пункт «Стать хостом» → выбрать его.

Скрипт:

1. Сделает `git pull`.
2. Проверит, есть ли живой хост по TTL.
3. Если хоста нет:
   - скопирует `saves/latest.zip` в локальный `shared.zip`;
   - пометит себя как `online = true` и запушит;
   - запустит Factorio с этим сейвом;
   - будет каждые 3 минуты обновлять `last_seen` (heartbeat);
   - когда Factorio закроется:
     - сохранит новую версию сейва в `saves/shared_...`;
     - обновит `saves/latest.zip`;
     - выставит `online = false`;
     - запушит всё в GitHub и покажет уведомление.

#### Windows

```powershell
cd C:\Users\USERNAME\factorio-shared
.actorio-sync.ps1
```

В интерактивном меню:

- если хоста нет → выбрать «Стать хостом».

Скрипт:

1. Сделает `git pull`.
2. Проверит `host.json` и TTL.
3. Если хоста нет:
   - скопирует `saves\latest.zip` в локальный `shared.zip`;
   - пометит себя как `online = true` и запушит;
   - подскажет, что нужно вручную запустить Factorio и открыть `shared.zip`.
4. После окончания игры надо выполнить:

   ```powershell
   .actorio-sync.ps1 push-save
   ```

   Это:
   - сохранит новую версию сейва (`shared_...`);
   - обновит `latest.zip`;
   - выставит `online = false`;
   - запушит изменения.

---

### Клиент (подключиться к уже запущенному хосту)

На любой системе:

#### macOS

```bash
cd ~/factorio-shared
./factorio-sync play
```

#### Windows

```powershell
cd C:\Users\USERNAME\factorio-shared
.actorio-sync.ps1 play
```

Скрипт покажет:

- есть ли живой хост;
- имя машины (`host_name`);
- время последней активности (`last_seen`).

Дальше:

1. Запустить Factorio.
2. Зайти в **Multiplayer → LAN**.
3. Подключиться к машине с указанным `host_name` (по LAN).

---

## Как добавить друга

1. На GitHub в репозитории:
   - **Settings → Collaborators → Add people**.
2. Ввести его GitHub-логин.
3. Выдать права как минимум **Write**.

Дальше друг делает:

```bash
git clone https://github.com/USER/factorio-shared.git
```

и пользуется скриптами так же, как ты.

---

## Типичные проблемы и решения

### 1) `error: cannot pull with rebase: You have unstaged changes`

Значит, в репозитории есть незакоммиченные изменения.

Решение:

```bash
git status                # посмотреть, что изменено
# если изменения нужны:
git add .
git commit -m "local changes"
git pull --rebase

# если изменения не нужны:
git restore .
git pull --rebase
```

### 2) На Windows PowerShell пишет, что нельзя запускать скрипты

Нужно один раз выполнить **от администратора**:

```powershell
Set-ExecutionPolicy RemoteSigned
```

### 3) Нет файла `saves/latest.zip`

Нужно:

- либо руками положить первый сейв (`shared.zip`) и сделать `push-save`,
- либо один из игроков-хостов должен отыграть и запушить сейв.

---

## Лицензия

Проект может использовать любую лицензию по твоему выбору.  
Если не хочется заморачиваться — можно добавить файл `LICENSE` с текстом [MIT License](https://opensource.org/licenses/MIT).
