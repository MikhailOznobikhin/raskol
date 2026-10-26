# Единая точка сборки/проверки проекта. Подробнее: README.md, ROADMAP.md §1.
# Примеры:
#   .\build.ps1 -Import            # импорт ресурсов / регистрация классов
#   .\build.ps1 -Test              # автотест прохождения (headless)
#   .\build.ps1 -Shots             # 3 скриншота в tools\shot_3d_*.png
#   .\build.ps1 -Assets            # регенерация текстур/арт/звука
#   .\build.ps1 -Export            # полная сборка build\Raskol.exe
#   .\build.ps1 -Assets -Export    # всё вместе
param(
    [switch]$Import,
    [switch]$Test,
    [switch]$Shots,
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

if ($Assets) {
    & $py (Join-Path $ws 'src\build_3d_textures.py')
    & $py (Join-Path $ws 'src\build_menu_bg.py')
    & $py (Join-Path $ws 'src\build_cinematic.py')
    & $py (Join-Path $ws 'src\audio\build_audio.py')
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
    if ($out -match 'TEST DONE escaped=true') {
        Write-Host '[OK] TEST: TEST DONE escaped=true' -ForegroundColor Green
    } else {
        throw 'Автотест НЕ зелёный (ожидание: "TEST DONE escaped=true"). Лог: tools\last_test.log'
    }
}

if ($Shots) {
    G @('--path', $ws, '--resolution', '1280x720', '--', '--shots')
    Write-Host '[OK] Скриншоты: tools\shot_3d_*.png' -ForegroundColor Green
}

if ($Export) {
    G @('--headless', '--path', $ws, '--import')
    G @('--headless', '--path', $ws, '--export-release', 'Windows Desktop', (Join-Path $ws 'build\Raskol.exe'))
    Write-Host '[OK] build\Raskol.exe собран (~110 МБ)' -ForegroundColor Green
}

if (-not ($Import -or $Test -or $Shots -or $Assets -or $Export)) {
    Write-Host 'Укажи хотя бы один флаг: -Import | -Test | -Shots | -Assets | -Export (см. header файла)'
}
