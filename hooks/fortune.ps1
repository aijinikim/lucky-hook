# SessionStart 훅 진입점: 오늘 아직 카드를 고르지 않았으면 카드 뽑기 운세 팝업(fortune_cards.ps1)을 별도 프로세스로 띄우고 바로 종료한다.
# 오늘 이미 골랐으면 팝업을 띄우지 않는다 (하루 한 번). 결과는 ~/.claude/lucky-hook/today.json에 있다.
$ErrorActionPreference = 'SilentlyContinue'

try {
    # 훅 JSON은 쓰지 않지만, 파이프가 막히지 않도록 stdin은 끝까지 읽어 둔다
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    $null = [Console]::In.ReadToEnd()

    $file = Join-Path $HOME '.claude\lucky-hook\today.json'
    if (Test-Path $file) {
        $saved = $null
        try { $saved = [IO.File]::ReadAllText($file, (New-Object Text.UTF8Encoding($false))) | ConvertFrom-Json } catch {}
        if ($saved -and $saved.date -eq (Get-Date -Format 'yyyy-MM-dd')) { exit 0 }
    }

    $cards = Join-Path $PSScriptRoot 'fortune_cards.ps1'
    $argList = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden',
        '-File', "`"$cards`""
    )
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -WindowStyle Hidden
} catch {}

exit 0
