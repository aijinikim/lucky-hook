# 세션 시작 시 "오늘의 운세" 카드 3장을 펼친다. 한 장을 고르면 뒤집히며 운세가 나오고, 결과는 ~/.claude/lucky-hook/today.json에 저장된다.
# 오늘 이미 골랐거나 다른 세션의 팝업이 떠 있으면 아무것도 띄우지 않는다 (하루 한 번, 한 창만).
# 고르지 않고 닫으면 저장하지 않으므로 다음 세션에서 다시 고를 수 있다.
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, PresentationCore
[System.Windows.Forms.Application]::EnableVisualStyles()

# 둥근 사각형 경로 (r = 모서리 반지름) — popup.ps1과 동일
function New-RoundedPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $d = $r * 2
    $p = New-Object Drawing.Drawing2D.GraphicsPath
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    $p
}

function New-Rect($x, $y, $w, $h) { New-Object Drawing.Rectangle([int]$x, [int]$y, [int]$w, [int]$h) }

# 기본 운세 목록 (~/.claude/lucky-hook/fortunes.json이 있으면 아래에서 그 목록으로 바뀐다)
$messages = @(
    '미뤄두던 리팩터링이 술술 풀리는 날', '작은 커밋이 큰 성과로 이어지는 날', '처음 보는 에러와도 금방 친해지는 날',
    '질문 하나가 막힌 길을 뚫어 주는 날', '오늘 쓴 코드가 내일의 나를 구하는 날', 'README를 읽으면 답이 보이는 날',
    '천천히 가도 결국 배포에 닿는 날', '새 라이브러리와 궁합이 좋은 날', '동료의 한마디가 힌트가 되는 날',
    '실습 결과가 기대 이상으로 나오는 날', '오래된 버그가 스스로 정체를 드러내는 날', '잠깐의 휴식이 최고의 디버거인 날',
    '복붙보다 직접 타이핑이 빛나는 날', '테스트가 초록불로 가득한 날', '오늘 배운 한 줄이 오래 남는 날'
)
$codings = @(
    '버그가 금방 잡혀요', '커밋 전에 diff를 한 번 더 보세요', 'print 한 줄이 정답을 알려 줘요',
    '변수 이름을 잘 지으면 운이 트여요', '오타 하나가 숨어 있어요, 꼼꼼히!', 'git pull 먼저 하면 평화로워요',
    '들여쓰기에 행운이 깃들어 있어요', '에러 메시지를 끝까지 읽으면 길이 보여요', '오늘은 Claude와 호흡이 잘 맞아요',
    '작게 나눠 실행하면 술술 풀려요', 'pip install이 한 번에 성공해요', '주석 한 줄이 내일의 시간을 아껴요'
)
$colors = @('코랄', '민트', '라벤더', '하늘색', '레몬', '올리브', '네이비', '버건디', '피치', '실버')
$keys   = @('Ctrl+Z', 'Ctrl+S', 'F5', 'Tab', 'Ctrl+C', 'Ctrl+Shift+P', 'Alt+Tab', 'Esc', 'Ctrl+/', 'Enter')

$fortuneDir  = Join-Path $HOME '.claude\lucky-hook'  # 플러그인 폴더는 업데이트 때 교체되므로 밖에 둔다
$fortuneFile = Join-Path $fortuneDir 'today.json'
$soundFile   = Join-Path $PSScriptRoot 'sounds\ding.mp3'  # 효과음 (mp3·wav 모두 가능)
$utf8        = New-Object Text.UTF8Encoding($false)
$now         = Get-Date
$today       = $now.ToString('yyyy-MM-dd')
$dateText    = "$today ($('일월화수목금토'[[int]$now.DayOfWeek]))"
$closeAfter  = 15    # 카드를 뒤집은 뒤 자동으로 닫히기까지 (초)
$idleLimit   = 180   # 고르지 않고 방치하면 저장 없이 조용히 닫힘 (초)

# 사용자 운세 목록: fortunes.json에 적은 목록이 기본 목록을 대신한다. 빠졌거나 빈 목록, 읽지 못한 파일은 기본값 그대로
$customFile = Join-Path $fortuneDir 'fortunes.json'
if (Test-Path $customFile) {
    try {
        $custom = [IO.File]::ReadAllText($customFile, $utf8) | ConvertFrom-Json
        foreach ($name in 'messages', 'codings', 'colors', 'keys') {
            $list = @($custom.$name | Where-Object { $_ -is [string] -and $_.Trim() })
            if ($list.Count) { Set-Variable -Name $name -Value $list }
        }
    } catch {}
}

# 세션을 여러 개 동시에 열어도 팝업은 하나만: 이미 떠 있으면 바로 종료
$mutex = New-Object Threading.Mutex($false, 'Local\LuckyHookFortuneCards')
try { $isOwner = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $isOwner = $true }
if (-not $isOwner) { exit 0 }

# 오늘 이미 골랐으면 띄우지 않는다 (fortune.ps1이 확인한 뒤 다른 창에서 골랐을 수도 있어 한 번 더 본다)
if (Test-Path $fortuneFile) {
    try {
        if (([IO.File]::ReadAllText($fortuneFile, $utf8) | ConvertFrom-Json).date -eq $today) { exit 0 }
    } catch {}
}

$fortune = $null
$picked  = -1
$hover   = -1
$flip    = 0.0  # 0 = 뒷면, 1 = 앞면까지 다 뒤집힘
$seconds = $closeAfter
$idle    = 0

# 색상·폰트 (popup.ps1과 같은 팔레트 + 카드 앞뒷면 색)
$bg          = [Drawing.Color]::FromArgb(32, 33, 40)
$accent      = [Drawing.Color]::FromArgb(217, 119, 87)
$fg          = [Drawing.Color]::FromArgb(240, 240, 245)
$muted       = [Drawing.Color]::FromArgb(160, 163, 175)
$dim         = [Drawing.Color]::FromArgb(115, 118, 130)
$boxFill     = [Drawing.Color]::FromArgb(43, 44, 53)
$boxLine     = [Drawing.Color]::FromArgb(62, 64, 76)
$chipText    = [Drawing.Color]::FromArgb(247, 196, 176)
$backFill    = [Drawing.Color]::FromArgb(54, 40, 46)
$backLine    = [Drawing.Color]::FromArgb(120, 217, 119, 87)
$frontFill   = [Drawing.Color]::FromArgb(250, 243, 236)
$frontLine   = [Drawing.Color]::FromArgb(232, 208, 194)
$frontAccent = [Drawing.Color]::FromArgb(196, 92, 60)
$frontInk    = [Drawing.Color]::FromArgb(120, 100, 95)
$fontKr      = 'Malgun Gothic'
$titleFont   = New-Object Drawing.Font($fontKr, 14, [Drawing.FontStyle]::Bold)
$subFont     = New-Object Drawing.Font($fontKr, 10)
$smallFont   = New-Object Drawing.Font($fontKr, 9)
$tinyFont    = New-Object Drawing.Font($fontKr, 8)
$quoteFont   = New-Object Drawing.Font($fontKr, 11, [Drawing.FontStyle]::Bold)
$iconFont    = New-Object Drawing.Font('Segoe UI Symbol', 18, [Drawing.FontStyle]::Bold)
$backFont    = New-Object Drawing.Font('Segoe UI Symbol', 26)
$cornerFont  = New-Object Drawing.Font('Segoe UI Symbol', 9)
$glyphFont   = New-Object Drawing.Font('Segoe UI Symbol', 32)
$starFont    = New-Object Drawing.Font('Segoe UI Symbol', 12)
$TF          = [Windows.Forms.TextFormatFlags]
$alignC      = $TF::HorizontalCenter -bor $TF::VerticalCenter -bor $TF::NoPadding
$alignL      = $TF::Left -bor $TF::VerticalCenter -bor $TF::NoPadding -bor $TF::EndEllipsis
$alignR      = $TF::Right -bor $TF::VerticalCenter -bor $TF::NoPadding

# 레이아웃
$width   = 480; $height = 470; $radius = 15
$cardW   = 124; $cardH = 170; $cardGap = 24; $cardY = 108; $lift = 8
$cardX0  = [int](($width - (3 * $cardW + 2 * $cardGap)) / 2)
$boxX    = 24; $boxY = 298; $boxW = $width - 48; $boxH = 106

function Get-Stars([int]$n) { ([string][char]0x2605 * $n) + ([string][char]0x2606 * (5 - $n)) }

# 총운에 따라 카드 앞면 그림: 5 ☀, 4 ✿, 3 ☁, 2 ☂
function Get-Glyph([int]$n) { [string][char](@{ 5 = 0x2600; 4 = 0x273F; 3 = 0x2601; 2 = 0x2602 }[$n]) }

function Draw-Text($g, $text, $font, $rect, $color, $flags) {
    [Windows.Forms.TextRenderer]::DrawText($g, [string]$text, $font, $rect, $color, $flags)
}

# 카드 i의 위치 (마우스를 올렸거나 고른 카드는 살짝 위로 뜬다)
function Get-CardRect([int]$i) {
    $y = $cardY
    if ($i -eq $script:hover -or $i -eq $script:picked) { $y -= $lift }
    New-Rect ($cardX0 + $i * ($cardW + $cardGap)) $y $cardW $cardH
}

# 좌표 아래에 있는 카드 번호 (없으면 -1). 뜬 카드도 잡히도록 위로 lift만큼 넓게 본다
function Find-Card($pt) {
    for ($i = 0; $i -lt 3; $i++) {
        if ((New-Rect ($cardX0 + $i * ($cardW + $cardGap)) ($cardY - $lift) $cardW ($cardH + $lift)).Contains($pt)) { return $i }
    }
    -1
}

function Draw-Back($g, $r, [int]$i) {
    $pen = New-Object Drawing.Pen($backLine, 1)
    $g.DrawPath($pen, (New-RoundedPath ($r.X + 8) ($r.Y + 8) ($r.Width - 16) ($r.Height - 16) 8))
    $pen.Dispose()
    Draw-Text $g ([char]0x2605) $backFont (New-Rect $r.X $r.Y $r.Width ($r.Height - 10)) $accent $alignC
    $sparkle = [char]0x2726
    foreach ($p in @(@(14, 14), @(($r.Width - 30), 14), @(14, ($r.Height - 30)), @(($r.Width - 30), ($r.Height - 30)))) {
        Draw-Text $g $sparkle $cornerFont (New-Rect ($r.X + $p[0]) ($r.Y + $p[1]) 16 16) $chipText $alignC
    }
    Draw-Text $g ($i + 1) $smallFont (New-Rect $r.X ($r.Y + $r.Height - 34) $r.Width 20) $dim $alignC
}

function Draw-Front($g, $r) {
    $f = $script:fortune
    $pen = New-Object Drawing.Pen($frontLine, 1)
    $g.DrawPath($pen, (New-RoundedPath ($r.X + 8) ($r.Y + 8) ($r.Width - 16) ($r.Height - 16) 8))
    $pen.Dispose()
    Draw-Text $g (Get-Glyph $f.stars) $glyphFont (New-Rect $r.X ($r.Y + 20) $r.Width 60) $frontAccent $alignC
    Draw-Text $g (Get-Stars $f.stars) $starFont (New-Rect $r.X ($r.Y + 88) $r.Width 24) $frontAccent $alignC
    Draw-Text $g '총운' $smallFont (New-Rect $r.X ($r.Y + 112) $r.Width 20) $frontInk $alignC
    Draw-Text $g "No.$($f.card)" $tinyFont (New-Rect $r.X ($r.Y + $r.Height - 32) $r.Width 18) $frontInk $alignC
}

function Draw-Card($g, [int]$i) {
    $r = Get-CardRect $i
    $front = $false; $scale = 1.0
    if ($i -eq $script:picked) {
        # 뒤집기: 폭이 cos 곡선으로 줄었다가 늘어나고, 절반을 넘기면 앞면으로 바뀐다
        $scale = [Math]::Abs([Math]::Cos([Math]::PI * $script:flip))
        $front = $script:flip -ge 0.5
    }
    $w = [int]($r.Width * $scale)
    if ($w -lt 2) { return }
    $x = $r.X + [int](($r.Width - $w) / 2)
    $path = New-RoundedPath $x $r.Y $w $r.Height 12

    $brush = New-Object Drawing.SolidBrush($(if ($front) { $frontFill } else { $backFill }))
    $g.FillPath($brush, $path); $brush.Dispose()
    $pen = if ($i -eq $script:hover) { New-Object Drawing.Pen($chipText, 2.5) } else { New-Object Drawing.Pen($accent, 2) }
    $g.DrawPath($pen, $path); $pen.Dispose()

    # 뒤집히는 도중 폭이 좁을 때는 무늬를 그리지 않는다
    if ($scale -gt 0.6) {
        $cr = New-Rect $x $r.Y $w $r.Height
        if ($front) { Draw-Front $g $cr } else { Draw-Back $g $cr $i }
    }

    # 고르지 않은 카드는 흐리게
    if ($script:picked -ge 0 -and $i -ne $script:picked) {
        $brush = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(170, $bg))
        $g.FillPath($brush, $path); $brush.Dispose()
    }
}

function Draw-Result($g) {
    $f = $script:fortune
    $path = New-RoundedPath $boxX $boxY $boxW $boxH 10
    $brush = New-Object Drawing.SolidBrush($boxFill); $g.FillPath($brush, $path); $brush.Dispose()
    $pen = New-Object Drawing.Pen($boxLine, 1); $g.DrawPath($pen, $path); $pen.Dispose()

    $x = $boxX + 14; $w = $boxW - 28
    Draw-Text $g '오늘의 한마디' $tinyFont (New-Rect $x ($boxY + 8) $w 18) $dim $alignL
    # 굽은 따옴표는 PowerShell이 문자열 구분자로 읽으므로 문자 코드로 붙인다
    Draw-Text $g ([string][char]0x201C + $f.message + [char]0x201D) $quoteFont (New-Rect $x ($boxY + 26) $w 26) $fg $alignL
    Draw-Text $g "코딩운 · $($f.coding)" $smallFont (New-Rect $x ($boxY + 56) $w 20) $muted $alignL
    Draw-Text $g "행운의 색 $($f.color)  ·  숫자 $($f.number)  ·  키 $($f.key)" $smallFont (New-Rect $x ($boxY + 78) $w 20) $chipText $alignL
}

function Get-Subtitle {
    if ($script:flip -ge 1) { return "No.$($script:fortune.card) 카드를 골랐어요" }
    if ($script:picked -ge 0) { return '카드를 뒤집는 중…' }
    '카드를 한 장 고르면 오늘의 운세가 나옵니다'
}

function Get-Footer {
    if ($script:flip -ge 1) { return "$($script:seconds)초 후 자동으로 닫힘" }
    'Esc로 닫으면 다음 세션에서 다시 고를 수 있어요'
}

# 효과음 재생 (비동기, mp3 지원) — 파일이 없거나 재생에 실패하면 시스템 기본 알림음
function Play-Ding {
    try {
        if (-not (Test-Path $soundFile)) { throw 'no sound file' }
        $script:player = New-Object System.Windows.Media.MediaPlayer
        $script:player.Open([Uri]$soundFile)
        $script:player.Play()
        $script:soundClock = [Diagnostics.Stopwatch]::StartNew()
    } catch { [System.Media.SystemSounds]::Asterisk.Play() }
}

# 카드 i를 고른다: 운세를 뽑아 저장하고 뒤집기 애니메이션 시작
function Select-Card([int]$i) {
    if ($script:picked -ge 0) { return }
    $rng = New-Object Random
    $script:fortune = [pscustomobject][ordered]@{
        date     = $today
        card     = $i + 1
        stars    = $rng.Next(2, 6)
        message  = $messages[$rng.Next($messages.Count)]
        coding   = $codings[$rng.Next($codings.Count)]
        color    = $colors[$rng.Next($colors.Count)]
        number   = $rng.Next(1, 10)
        key      = $keys[$rng.Next($keys.Count)]
        sessions = @()  # fortune_context.ps1이 Claude에게 넘긴 세션 id 기록
    }
    try {
        New-Item -ItemType Directory -Force $fortuneDir | Out-Null
        [IO.File]::WriteAllText($fortuneFile, ($script:fortune | ConvertTo-Json -Depth 3), $utf8)
    } catch {}

    $script:picked = $i
    $script:hover  = -1
    $form.Cursor   = [Windows.Forms.Cursors]::Default
    $script:flipClock = [Diagnostics.Stopwatch]::StartNew()
    $anim.Start()
    Play-Ding
    $form.Invalidate()
}

$form = New-Object Windows.Forms.Form
$form.FormBorderStyle = 'None'
$form.StartPosition   = 'Manual'
$form.TopMost         = $true
$form.ShowInTaskbar   = $false
$form.KeyPreview      = $true
$form.ClientSize      = New-Object Drawing.Size($width, $height)
$form.BackColor       = $bg
$form.Text            = '오늘의 운세'
$form.Region          = New-Object Drawing.Region (New-RoundedPath 0 0 $width $height $radius)
# 애니메이션 깜빡임 방지 (DoubleBuffered는 protected 속성이라 리플렉션으로 켠다)
$form.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'NonPublic,Instance').SetValue($form, $true, $null)

# 가장 오른쪽 모니터의 작업 영역 가운데에 배치 (모니터가 하나면 그 화면 가운데)
$work = ([Windows.Forms.Screen]::AllScreens | Sort-Object { $_.Bounds.X } | Select-Object -Last 1).WorkingArea
$form.Location = New-Object Drawing.Point(
    [int]($work.X + ($work.Width - $width) / 2),
    [int]($work.Y + ($work.Height - $height) / 2))

$form.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $pen = New-Object Drawing.Pen($accent, 2)
    $g.DrawPath($pen, (New-RoundedPath 1 1 ($width - 2) ($height - 2) ($radius - 1)))
    $pen.Dispose()

    Draw-Text $g ([char]0x2605) $iconFont (New-Rect 22 16 34 34) $accent $alignC
    Draw-Text $g '오늘의 운세' $titleFont (New-Rect 58 20 240 30) $fg $alignL
    Draw-Text $g $dateText $smallFont (New-Rect ($width - 176) 26 150 22) $dim $alignR
    Draw-Text $g (Get-Subtitle) $subFont (New-Rect 26 62 ($width - 52) 22) $muted $alignL

    for ($i = 0; $i -lt 3; $i++) { Draw-Card $g $i }

    if ($script:flip -ge 1) { Draw-Result $g }
    elseif ($script:picked -lt 0) {
        Draw-Text $g '마음이 가는 카드를 클릭하세요  (1 · 2 · 3 키도 가능)' $smallFont (New-Rect $boxX $boxY $boxW 40) $dim $alignC
    }

    Draw-Text $g (Get-Footer) $smallFont (New-Rect 26 ($height - 44) 320 22) $dim $alignL
})

$ok = New-Object Windows.Forms.Button
$ok.Text      = '나중에'
$ok.Location  = New-Object Drawing.Point(($width - 112), ($height - 50))
$ok.Size      = New-Object Drawing.Size(88, 32)
$ok.Font      = New-Object Drawing.Font($fontKr, 10, [Drawing.FontStyle]::Bold)
$ok.FlatStyle = 'Flat'
$ok.FlatAppearance.BorderSize = 0
$ok.BackColor = $accent
$ok.ForeColor = [Drawing.Color]::White
$ok.Cursor    = [Windows.Forms.Cursors]::Hand
$ok.Region    = New-Object Drawing.Region (New-RoundedPath 0 0 88 32 8)
$ok.Add_Click({ $form.Close() })
$form.Controls.Add($ok)
$form.AcceptButton = $ok

# 마우스: 올리면 카드가 뜨고, 클릭하면 고른다
$form.Add_MouseMove({
    param($s, $e)
    if ($script:picked -ge 0) { return }
    $h = Find-Card $e.Location
    if ($h -ne $script:hover) {
        $script:hover = $h
        $form.Cursor = if ($h -ge 0) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
        $form.Invalidate()
    }
})
$form.Add_MouseLeave({
    if ($script:picked -lt 0 -and $script:hover -ge 0) { $script:hover = -1; $form.Invalidate() }
})
$form.Add_MouseClick({
    param($s, $e)
    if ($script:picked -lt 0) {
        $h = Find-Card $e.Location
        if ($h -ge 0) { Select-Card $h }
    }
})

# 키보드: 1·2·3으로 고르기, Esc로 닫기
$form.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq 'Escape') { $form.Close(); return }
    if ($script:picked -ge 0) { return }
    $n = switch ($e.KeyCode.ToString()) {
        { $_ -in 'D1', 'NumPad1' } { 0 }
        { $_ -in 'D2', 'NumPad2' } { 1 }
        { $_ -in 'D3', 'NumPad3' } { 2 }
        default { -1 }
    }
    if ($n -ge 0) { Select-Card $n }
})

# 뒤집기 애니메이션 (약 280ms)
$anim = New-Object Windows.Forms.Timer
$anim.Interval = 15
$anim.Add_Tick({
    $script:flip = [Math]::Min(1.0, $script:flipClock.ElapsedMilliseconds / 280)
    if ($script:flip -ge 1) {
        $anim.Stop()
        $ok.Text = '확인'
        $script:seconds = $closeAfter
    }
    $form.Invalidate()
})

# 1초 타이머: 뒤집은 뒤에는 자동 닫힘 카운트다운, 고르기 전에는 방치 시간 측정
$clock = New-Object Windows.Forms.Timer
$clock.Interval = 1000
$clock.Add_Tick({
    if ($script:flip -ge 1) {
        $script:seconds--
        if ($script:seconds -le 0) { $clock.Stop(); $form.Close(); return }
        $form.Invalidate()
    } elseif ($script:picked -lt 0) {
        $script:idle++
        if ($script:idle -ge $idleLimit) { $clock.Stop(); $form.Close() }
    }
})

# 숨김 프로세스로 실행되면 첫 ShowWindow가 숨김 설정을 물려받으므로, 한 번 숨겼다가 다시 표시한다
$form.Add_Shown({
    $form.Hide(); $form.Show(); $form.Activate(); $clock.Start()
})
[System.Windows.Forms.Application]::Run($form)

# 팝업을 바로 닫아도 효과음이 끊기지 않도록 재생이 끝날 때까지 대기 (최대 5초)
if ($script:player -and $script:soundClock) {
    $length = if ($script:player.NaturalDuration.HasTimeSpan) { $script:player.NaturalDuration.TimeSpan.TotalMilliseconds } else { 3000 }
    $remain = [Math]::Min($length, 5000) - $script:soundClock.ElapsedMilliseconds
    if ($remain -gt 0) { Start-Sleep -Milliseconds ([int]$remain) }
    $script:player.Close()
}
$anim.Dispose()
$clock.Dispose()
$form.Dispose()
$mutex.ReleaseMutex()
$mutex.Dispose()
