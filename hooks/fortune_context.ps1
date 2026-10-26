# UserPromptSubmit 훅: 오늘 뽑은 운세 카드(~/.claude/lucky-hook/today.json)를 세션당 한 번 Claude 컨텍스트로 넘긴다.
# 파일이 없거나, 날짜가 지났거나, 이미 넘긴 세션이면 아무것도 출력하지 않는다. 어떤 경우에도 프롬프트를 막지 않는다.
$ErrorActionPreference = 'SilentlyContinue'

try {
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()

    $data = $null
    if ($raw) { try { $data = $raw | ConvertFrom-Json } catch {} }
    $sessionId = if ($data -and $data.session_id) { [string]$data.session_id } else { '' }

    $file = Join-Path $HOME '.claude\lucky-hook\today.json'
    if (-not (Test-Path $file)) { exit 0 }

    $utf8 = New-Object Text.UTF8Encoding($false)
    $f = [IO.File]::ReadAllText($file, $utf8) | ConvertFrom-Json
    $today = Get-Date -Format 'yyyy-MM-dd'
    if ($f.date -ne $today) { exit 0 }

    $sessions = @($f.sessions | Where-Object { $_ })
    if ($sessionId -and $sessions -contains $sessionId) { exit 0 }

    # 이 세션에 넘겼다고 기록
    if ($sessionId) {
        $f.sessions = @($sessions + $sessionId)
        [IO.File]::WriteAllText($file, ($f | ConvertTo-Json -Depth 3), $utf8)
    }

    $stars = ([string][char]0x2605 * $f.stars) + ([string][char]0x2606 * (5 - $f.stars))
    $context = "사용자가 오늘($today) 세션 시작 팝업에서 뽑은 운세 카드: $($f.card)번 카드, " +
        "총운 $stars, 한마디 `"$($f.message)`", 코딩운 `"$($f.coding)`", " +
        "행운의 색 $($f.color), 행운의 숫자 $($f.number), 행운의 키 $($f.key). " +
        "사용자가 운세를 물으면 이 내용대로 답하고, 먼저 꺼내지는 말 것."

    $out = @{ hookSpecificOutput = @{ hookEventName = 'UserPromptSubmit'; additionalContext = $context } }
    [Console]::OutputEncoding = $utf8  # BOM 없는 UTF-8 (BOM이 붙으면 JSON 파싱이 깨진다)
    [Console]::Out.Write(($out | ConvertTo-Json -Depth 3 -Compress))
} catch {}

exit 0
