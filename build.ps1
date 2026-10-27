# Единая точка сборки/проверки проекта. Подробнее: README.md, ROADMAP.md §1.
# Примеры:
#   .\build.ps1 -Import            # импорт ресурсов / регистрация классов
#   .\build.ps1 -Test              # автотест прохождения (headless)
#   .\build.ps1 -Shots             # 3 скриншота в tools\shot_3d_*.png
#   .\build.ps1 -Models            # проверка .glb: скины, клипы, кости оружия
#   .\build.ps1 -Assets            # регенерация текстур/арт/звука
#   .\build.ps1 -Export            # полная сборка build\Raskol.exe
#   .\build.ps1 -Assets -Export    # всё вместе
param(
    [switch]$Import,
    [switch]$Test,
    [switch]$Shots,
    [switch]$Models,
    [switch]$Assets,
    [switch]$Export
)
$ErrorActionPreference = 'Stop'

$ws = $PSScriptRoot
$godot = Join-Path $ws 'tools\godot\Godot_v4.4.1-stable_win64_console.exe'
$py = Join-Path $env:USERPROFILE '.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'

# Godot требует пользовательские каталоги; в песочнице подменяем их на tools\
$env:APPDATA = Join-Path $ws 'tools\appdata'
$env:LOCALAPPDATA = Join-Path $ws 'tools\localappdata'
# --export-release собирает PCK во временном каталоге; системный %TEMP% в
# песочнице недоступен на запись, поэтому уводим его тоже в tools\.
$env:TMP = Join-Path $ws 'tools\temp'
$env:TEMP = $env:TMP
if (-not (Test-Path $env:TMP)) { New-Item -ItemType Directory -Path $env:TMP | Out-Null }

# Godot пишет часть лога в stderr; с EAP='Stop' PowerShell падает на любой строке,
# поэтому для нативных вызовов сравниваем не stderr, а код возврата.
function G([string[]]$Args) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $godot @Args 2>&1 | Out-Host
    $ErrorActionPreference = $prev
    if ($LASTEXITCODE -ne 0) { throw "Godot вернул код $LASTEXITCODE" }
}

if (-not (Test-Path $godot)) { throw "Нет движка: $godot (см. ROADMAP.md §1)" }

# Проверка моделей: битый .glb/без скина/без клипов иначе всплывает только в игре.
# Идёт и при -Test, чтобы «модель не загрузилась» ловилось до коммита.
if ($Models -or $Test) {
    & $py (Join-Path $ws 'tools\check_models.py')
    if ($LASTEXITCODE -ne 0) { throw 'Проверка моделей не пройдена (см. вывод выше)' }
    Write-Host '[OK] Модели проверены' -ForegroundColor Green
}

if ($Assets) {
    & $py (Join-Path $ws 'src\build_3d_textures.py')
    & $py (Join-Path $ws 'src\build_menu_bg.py')
    & $py (Join-Path $ws 'src\build_cinematic.py')
    & $py (Join-Path $ws 'src\audio\build_audio.py')
    # SFX v2 собираются из CC0-сэмплов (tools\cc0) и должны идти ПОСЛЕ
    # процедурного генератора, иначе он перезапишет их старыми версиями.
    & $py (Join-Path $ws 'src\audio\build_audio_samples.py')
    if ($LASTEXITCODE -ne 0) { throw 'Генераторы ассетов упали' }
    Write-Host '[OK] Ассеты перегенерированы' -ForegroundColor Green
}

if ($Import) {
    G @('--headless', '--path', $ws, '--import')
    Write-Host '[OK] Импорт пройден' -ForegroundColor Green
}

if ($Test) {
    if ($Import) { # class_name регистрируется только после импорта
        G @('--headless', '--path', $ws, '--import')
    }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & $godot --headless --path $ws -- --test3d 2>&1 | Out-String
    $ErrorActionPreference = $prev
    $out | Set-Content -Path (Join-Path $ws 'tools\last_test.log') -Encoding UTF8
    Write-Host $out
    # Прохождение сценария не значит, что падений не было: ошибка в _ready
    # autoload (например, неверное свойство AudioStreamPlayer3D) роняла только
    # звук, а «TEST DONE» при этом печатался.
    if ($out -match 'SCRIPT ERROR') {
        throw 'В логе автотеста есть SCRIPT ERROR — по AGENTS.md это блокер. Лог: tools\last_test.log'
    }
    if ($out -match 'TEST DONE escaped=true') {
        Write-Host '[OK] TEST: TEST DONE escaped=true' -ForegroundColor Green
    } else {
        throw 'Автотест НЕ зелёный (ожидание: "TEST DONE escaped=true"). Лог: tools\last_test.log'
    }
}

if ($Shots) {
    # Окно может не открыться (нет GPU/дисплея, занят другой экземпляр) — игра
    # тогда выходит с кодом 0 и без кадров. Поэтому проверяем не код возврата,
    # а сам лог: должны быть строки SHOT от _shots_mode(). Одна повторная попытка.
    # Запуск только через_job с дедлайном: зависшее окно иначе остаётся
    # открытым на весь ноутбук.
    for ($try = 1; $try -le 2; $try++) {
        $jobStart = Get-Date
        $job = Start-Job -ScriptBlock {
            param($g, $ws)
            $env:APPDATA = Join-Path $ws 'tools\appdata'
            $env:LOCALAPPDATA = Join-Path $ws 'tools\localappdata'
            $env:TEMP = Join-Path $ws 'tools\temp'
            & $g --path $ws --resolution 1280x720 -- --shots 2>&1
        } -ArgumentList $godot, $ws
        $done = Wait-Job $job -Timeout 300
        $out = (Receive-Job $job | Out-String)
        Remove-Job $job -Force
        if ($null -eq $done) {
            # Снимаем только те окна, которые подняли мы: в этом дереве
            # параллельно работает другая сессия со своим редактором Godot.
            foreach ($proc in @(Get-Process | Where-Object { $_.ProcessName -like 'Godot_v4.4.1*' })) {
                try {
                    if ($proc.StartTime -gt $jobStart) { Stop-Process -Id $proc.Id -Force }
                } catch { }
            }
            $out += "`nSHOT watchdog: съёмка не уложилась в 300 с, Godot снят принудительно`n"
        }
        $out | Set-Content -Path (Join-Path $ws 'tools\last_shots.log') -Encoding UTF8
        $shotCount = ([regex]::Matches($out, '(?m)^SHOT 3d_')).Count
        if ($shotCount -gt 0 -and $out -notmatch 'SCRIPT ERROR') {
            break
        }
        if ($try -eq 1) { Write-Host 'Кадры не сняты с первой попытки — повтор...' -ForegroundColor Yellow }
    }
    Write-Host $out
    if ($shotCount -eq 0 -or $out -match 'SCRIPT ERROR') {
        throw "Скриншоты не сняты (строк SHOT: $shotCount). Лог: tools\last_shots.log"
    }
    Write-Host "[OK] Скриншоты: tools\shot_3d_*.png (кадров: $shotCount)" -ForegroundColor Green
}

if ($Export) {
    $exe = Join-Path $ws 'build\Raskol.exe'
    # Экспорт молча выходил с кодом 0, оставляя на диске вчерашний exe:
    # проверяем не код возврата, а что файл действительно перезаписан.
    $before = if (Test-Path $exe) { (Get-Item $exe).LastWriteTime } else { [datetime]::MinValue }
    $started = Get-Date
    G @('--headless', '--path', $ws, '--import')
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & $godot --headless --path $ws --export-release 'Windows Desktop' $exe 2>&1 | Out-String
    $ErrorActionPreference = $prev
    $out | Set-Content -Path (Join-Path $ws 'tools\last_export.log') -Encoding UTF8
    if (-not (Test-Path $exe)) { throw "Экспорт не создал $exe — см. tools\last_export.log" }
    $after = (Get-Item $exe).LastWriteTime
    if ($after -lt $started.AddSeconds(-5)) {
        throw "Экспорт не перезаписал exe (mtime=$after, сборка начата $started) — см. tools\last_export.log"
    }
    if ($out -match 'ERROR|Cannot find export template|missing') {
        throw "В логе экспорта есть ошибки — см. tools\last_export.log"
    }
    $mb = [math]::Round((Get-Item $exe).Length / 1MB, 1)
    Write-Host "[OK] build\Raskol.exe собран ($mb МБ, $after)" -ForegroundColor Green
}

if (-not ($Import -or $Test -or $Shots -or $Models -or $Assets -or $Export)) {
    Write-Host 'Укажи хотя бы один флаг: -Import | -Test | -Shots | -Models | -Assets | -Export (см. header файла)'
}
