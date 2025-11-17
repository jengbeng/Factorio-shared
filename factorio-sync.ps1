Param(
    [Parameter(Position=0)]
    [string]$Command = "auto"
)

$ErrorActionPreference = "Stop"

# ===== НАСТРОЙКИ =====

$FactorioSavesDefault = Join-Path $env:APPDATA "Factorio\saves"
if (-not $env:FACTORIO_SAVES_DIR) {
    $Global:FACTORIO_SAVES_DIR = $FactorioSavesDefault
} else {
    $Global:FACTORIO_SAVES_DIR = $env:FACTORIO_SAVES_DIR
}

if (-not $env:SHARED_SAVE_NAME) {
    $Global:SHARED_SAVE_NAME = "shared.zip"
} else {
    $Global:SHARED_SAVE_NAME = $env:SHARED_SAVE_NAME
}

if (-not $env:FACTORIO_PORT) {
    $Global:FACTORIO_PORT = 34197
} else {
    $Global:FACTORIO_PORT = [int]$env:FACTORIO_PORT
}

if (-not $env:HEARTBEAT_INTERVAL_SEC) {
    $Global:HEARTBEAT_INTERVAL_SEC = 180
} else {
    $Global:HEARTBEAT_INTERVAL_SEC = [int]$env:HEARTBEAT_INTERVAL_SEC
}

if (-not $env:HOST_TTL_SEC) {
    $Global:HOST_TTL_SEC = 210
} else {
    $Global:HOST_TTL_SEC = [int]$env:HOST_TTL_SEC
}

$Script:RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Script:RepoDir

# ===== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =====

function Show-Usage {
    Write-Host @"
Использование:
  .\factorio-sync.ps1              - интерактивный режим (рекомендуется)
  .\factorio-sync.ps1 init         - первичная настройка репозитория и GitHub
  .\factorio-sync.ps1 host         - стать хостом (Windows-версия, базовая)
  .\factorio-sync.ps1 play         - режим клиента (проверка статуса)
  .\factorio-sync.ps1 push-save    - ручной push сейва и offline-статуса

Переменные окружения (опционально):
  FACTORIO_SAVES_DIR
  SHARED_SAVE_NAME
  FACTORIO_PORT
  HEARTBEAT_INTERVAL_SEC
  HOST_TTL_SEC
"@
}

function Get-HostNameSimple {
    if ($env:COMPUTERNAME) { return $env:COMPUTERNAME }
    return [System.Net.Dns]::GetHostName()
}

function Get-NowUtcIso {
    (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function Copy-SaveFromRepoToFactorio {
    if (-not (Test-Path "saves\latest.zip")) {
        Write-Host "ВНИМАНИЕ: файл saves\latest.zip не найден в репозитории."
        return $false
    }
    if (-not (Test-Path $Global:FACTORIO_SAVES_DIR)) {
        New-Item -ItemType Directory -Path $Global:FACTORIO_SAVES_DIR | Out-Null
    }
    Copy-Item "saves\latest.zip" (Join-Path $Global:FACTORIO_SAVES_DIR $Global:SHARED_SAVE_NAME) -Force
    Write-Host "Сейв скопирован в: $($Global:FACTORIO_SAVES_DIR)\$($Global:SHARED_SAVE_NAME)"
    return $true
}

function Copy-SaveFromFactorioToRepo {
    $src = Join-Path $Global:FACTORIO_SAVES_DIR $Global:SHARED_SAVE_NAME
    if (-not (Test-Path $src)) {
        Write-Host "ВНИМАНИЕ: локальный сейв '$src' не найден."
        return $false
    }

    if (-not (Test-Path "saves")) {
        New-Item -ItemType Directory -Path "saves" | Out-Null
    }

    $existing = Get-ChildItem "saves" -Filter "shared*.zip" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "latest.zip" }

    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH-mm-ssZ")
    if (-not $existing) {
        $versionPath = "saves\shared.zip"
        Write-Host "Первое сохранение: $versionPath"
    } else {
        $versionPath = "saves\shared_$ts.zip"
        Write-Host "Новое сохранение: $versionPath"
    }

    Copy-Item $src $versionPath -Force
    Copy-Item $src "saves\latest.zip" -Force

    Write-Host "Локальный сейв скопирован:"
    Write-Host "  версия:  $versionPath"
    Write-Host "  latest:  saves\latest.zip"
    return $true
}

function Git-Update {
    & git pull --rebase 2>$null | Out-Null
}

function Read-HostStatus {
    $file = "meta\host.json"
    if (-not (Test-Path $file)) {
        return $null
    }
    $json = Get-Content $file -Raw | ConvertFrom-Json
    if (-not $json.online -or -not $json.last_seen) {
        return $null
    }
    return $json
}

function Write-HostStatus([bool]$Online, [string]$HostName) {
    if (-not (Test-Path "meta")) {
        New-Item -ItemType Directory -Path "meta" | Out-Null
    }
    $obj = [PSCustomObject]@{
        online    = $Online
        host_name = $HostName
        last_seen = Get-NowUtcIso
    }
    $obj | ConvertTo-Json | Set-Content "meta\host.json" -Encoding UTF8
}

function Test-HostStatusFresh($lastSeen) {
    $now = Get-Date
    $ls  = [datetime]::Parse($lastSeen).ToUniversalTime()
    $diff = ($now.ToUniversalTime() - $ls).TotalSeconds
    return ($diff -le $Global:HOST_TTL_SEC)
}

function Test-FactorioRunning {
    $p = Get-Process -Name "factorio" -ErrorAction SilentlyContinue
    return ($null -ne $p)
}

# ===== init =====

function Cmd-Init {
    Write-Host "=== factorio-sync (Windows): init ==="
    Write-Host "Текущая папка: $Script:RepoDir"
    Write-Host ""

    if (-not (Test-Path ".git")) {
        Write-Host "Здесь нет git-репозитория. Создаю..."
        & git init
        Write-Host ""
    }

    Write-Host "Проверяю origin..."
    $originOk = $true
    try {
        $originUrl = & git remote get-url origin 2>$null
    } catch {
        $originOk = $false
    }
    if ($originOk -and $originUrl) {
        Write-Host "origin уже настроен: $originUrl"
    } else {
        Write-Host "origin не настроен."
        $remoteUrl = Read-Host "Вставь URL репозитория на GitHub (или Enter, чтобы пропустить)"
        if ($remoteUrl) {
            & git remote add origin $remoteUrl
            Write-Host "Добавлен origin: $remoteUrl"
        } else {
            Write-Host "origin не настроен. Позже можно сделать:"
            Write-Host "  git remote add origin https://github.com/USER/REPO.git"
        }
    }

    Write-Host ""
    Write-Host "Создаю папки saves и meta..."
    if (-not (Test-Path "saves")) { New-Item -ItemType Directory -Path "saves" | Out-Null }
    if (-not (Test-Path "meta"))  { New-Item -ItemType Directory -Path "meta"  | Out-Null }
    Write-Host "Готово."
    Write-Host ""

    Write-Host "Дальше:"
    Write-Host "  .\factorio-sync.ps1        - интерактивный режим"
    Write-Host "  .\factorio-sync.ps1 host   - стать хостом"
    Write-Host "  .\factorio-sync.ps1 play   - клиент"
}

# ===== host (упрощённая версия на Windows) =====

function Cmd-Host {
    Write-Host "=== factorio-sync (Windows): host ==="
    Write-Host "FACTORIO_SAVES_DIR = $Global:FACTORIO_SAVES_DIR"
    Write-Host ""

    Write-Host "Шаг 1: git pull..."
    Git-Update
    Write-Host ""

    Write-Host "Шаг 2: проверяем host.json + TTL..."
    $st = Read-HostStatus
    if ($st) {
        if ($st.online -and (Test-HostStatusFresh $st.last_seen)) {
            Write-Host "Уже есть живой хост:"
            Write-Host "  host_name : $($st.host_name)"
            Write-Host "  last_seen : $($st.last_seen)"
            Write-Host ""
            Write-Host "Просто зайди в Factorio → Multiplayer → LAN и подключись к этой машине."
            return
        } else {
            Write-Host "Запись о хосте устарела или offline."
        }
    } else {
        Write-Host "host.json отсутствует или повреждён — считаем, что хоста нет."
    }
    Write-Host ""

    Write-Host "Шаг 3: копируем последний сейв в Factorio..."
    if (-not (Copy-SaveFromRepoToFactorio)) {
        Write-Host "Не удалось скопировать сейв. Останавливаюсь."
        return
    }
    Write-Host ""

    Write-Host "Шаг 4: помечаем себя как online и пушим..."
    $myHost = Get-HostNameSimple
    Write-HostStatus -Online $true -HostName $myHost
    & git add meta\host.json 2>$null
    & git commit -m "factorio-sync(win): host ONLINE ($myHost)" 2>$null
    Git-Update
    & git push 2>$null
    Write-Host "online-статус запушен."
    Write-Host ""

    # Здесь можно запускать Factorio через Steam или exe — оставляю настраиваемым:
    Write-Host "Теперь запусти Factorio вручную, загрузи сейв $($Global:SHARED_SAVE_NAME) и начни хостить LAN."
    Write-Host "После окончания игры выполни:"
    Write-Host "  .\factorio-sync.ps1 push-save"
}

function Cmd-PushSave {
    Write-Host "=== factorio-sync (Windows): push-save ==="
    $st = Read-HostStatus
    if ($st) { $hostName = $st.host_name } else { $hostName = Get-HostNameSimple }

    Copy-SaveFromFactorioToRepo | Out-Null
    Write-HostStatus -Online $false -HostName $hostName
    & git add saves meta\host.json 2>$null
    & git commit -m "factorio-sync(win): host OFFLINE + save ($hostName)" 2>$null
    Git-Update
    & git push 2>$null

    Write-Host "Сейв и offline-статус запушены."
}

function Cmd-Play {
    Write-Host "=== factorio-sync (Windows): play ==="
    Write-Host ""

    Write-Host "Шаг 1: git pull..."
    Git-Update
    Write-Host ""

    Write-Host "Шаг 2: читаем host.json..."
    $st = Read-HostStatus
    if (-not $st) {
        Write-Host "host.json нет — активного хоста нет."
        Write-Host "Кто-то должен выполнить: .\factorio-sync.ps1 host"
        return
    }

    $isFresh = $st.online -and (Test-HostStatusFresh $st.last_seen)

    Write-Host ("  host_name : {0}" -f $st.host_name)
    Write-Host ("  online    : {0}" -f $st.online)
    Write-Host ("  last_seen : {0}" -f $st.last_seen)

    if ($isFresh) {
        Write-Host "→ По TTL: хост считается ОНЛАЙН."
        Write-Host ""
        Write-Host "Действия:"
        Write-Host "  1) Запусти Factorio."
        Write-Host "  2) В мультиплеере выбери LAN и подключись к машине '$($st.host_name)'."
    } else {
        Write-Host "→ По TTL: хост считается OFFLINE или запись устарела."
        Write-Host "Кто-то должен выполнить: .\factorio-sync.ps1 host"
    }
}

function Cmd-Auto {
    Write-Host "=== factorio-sync (Windows): интерактивный режим ==="
    Write-Host ""

    if (-not (Test-Path ".git")) {
        Write-Host "Здесь ещё нет git-репозитория."
        Write-Host "Сначала выполни:"
        Write-Host "  .\factorio-sync.ps1 init"
        return
    }

    Write-Host "Шаг 1: git pull..."
    Git-Update
    Write-Host ""

    Write-Host "Шаг 2: состояние host.json:"
    $st = Read-HostStatus
    $fresh = $false
    if ($st) {
        Write-Host ("  host_name : {0}" -f $st.host_name)
        Write-Host ("  online    : {0}" -f $st.online)
        Write-Host ("  last_seen : {0}" -f $st.last_seen)
        if ($st.online -and (Test-HostStatusFresh $st.last_seen)) {
            $fresh = $true
            Write-Host "  → По TTL: хост считается ОНЛАЙН."
        } else {
            Write-Host "  → По TTL: хост считается OFFLINE или запись устарела."
        }
    } else {
        Write-Host "  host.json отсутствует — никто ещё не запускал сервер."
    }

    Write-Host ""
    Write-Host "Что ты хочешь сделать?"
    if ($fresh) {
        Write-Host "  1) Зайти как игрок на уже запущенный сервер."
        Write-Host "  2) Попробовать самому стать хостом."
    } else {
        Write-Host "  1) Стать хостом (запустить сервер на этом компьютере)."
    }
    Write-Host "  3) Принудительно запушить сейв и статус offline."
    Write-Host "  0) Выйти."
    Write-Host ""

    $choice = Read-Host "Выбери номер"

    switch ($choice) {
        "1" {
            if ($fresh) {
                Cmd-Play
            } else {
                Cmd-Host
            }
        }
        "2" {
            Cmd-Host
        }
        "3" {
            Cmd-PushSave
        }
        "0" {
            Write-Host "Выход."
        }
        default {
            Write-Host "Неизвестный выбор."
        }
    }
}

# ===== ДИСПЕТЧЕР КОМАНД =====

switch ($Command.ToLower()) {
    "init"      { Cmd-Init }
    "host"      { Cmd-Host }
    "play"      { Cmd-Play }
    "push-save" { Cmd-PushSave }
    "auto"      { Cmd-Auto }
    default     { Cmd-Auto }
}
