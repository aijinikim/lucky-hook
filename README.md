# lucky-hook 🔮

Claude Code 세션을 시작하면 **카드 3장 중 한 장을 골라 오늘의 운세**를 뽑는 플러그인입니다.
뽑은 카드는 프롬프트 입력창 위 오른쪽에 작은 **장신구**로 하루 종일 떠 있고, Claude에게 "오늘 운세 어때?"라고 물으면 같은 운세로 답해 줍니다.

> Windows 전용입니다 (PowerShell + Windows Forms 팝업).

## 설치

Claude Code 프롬프트에 입력합니다. 마켓플레이스를 추가할지 물으면 `y`, 그다음 설치 범위를 고르세요.

```
/plugin install lucky-hook --marketplace aijinikim/lucky-hook
```

두 단계로 설치해도 됩니다.

```
/plugin marketplace add aijinikim/lucky-hook
/plugin install lucky-hook@lucky-hook
```

터미널에서는 `claude plugin marketplace add aijinikim/lucky-hook` → `claude plugin install lucky-hook@lucky-hook`.

설치 후 Claude Code를 새로 시작하면 바로 카드가 펼쳐집니다.

## 이렇게 동작해요

| 언제 | 무엇을 |
|---|---|
| 새 세션 시작 · `/clear` | 뒷면 카드 3장 팝업. 클릭하거나 `1`·`2`·`3` 키로 고르면 카드가 뒤집히며 운세가 나옵니다 (총운 별점, 한마디, 코딩운, 행운의 색·숫자·키) |
| 카드를 고른 뒤 | 프롬프트 위 오른쪽에 미니 카드 장신구가 나타납니다. `[-]` 또는 `ctrl+x ctrl+a`로 접을 수 있어요 |
| 첫 메시지를 보낼 때 | 오늘의 운세를 Claude에게 조용히 전달합니다. 물어볼 때만 답하고 먼저 꺼내지는 않아요 |
| 같은 날 다시 세션을 열면 | 팝업이 뜨지 않습니다. **하루에 한 번만** 고를 수 있어요. 자정이 지나면 장신구가 사라지고, 다음 세션에서 새로 뽑습니다 |

```
                              ╭───────────╮
                              │ No.2      │
                              │ ☁  ★★★☆☆  │
                              │ 라벤더 · Ctrl+C│
                              ╰───────────╯ [-]
╭────────────────────────────────────────────╮
│ >                                          │
╰────────────────────────────────────────────╯
```

- 고르지 않고 **나중에**(또는 `Esc`)로 닫으면 저장하지 않으므로 다음 세션에서 다시 고를 수 있습니다. 3분 동안 그대로 두면 저절로 닫힙니다.
- 세션을 여러 개 동시에 열어도 팝업은 하나만 뜹니다.
- 뽑은 결과는 `%USERPROFILE%\.claude\lucky-hook\today.json`에 저장됩니다.

## 구성

```
.claude-plugin/plugin.json       플러그인 정보
.claude-plugin/marketplace.json  이 저장소를 마켓플레이스로 쓰기 위한 목록
hooks/hooks.json                 SessionStart · UserPromptSubmit 훅 + 장신구 모듈 등록
hooks/fortune.ps1                SessionStart: 오늘 아직 안 골랐으면 팝업을 띄움
hooks/fortune_cards.ps1          카드 3장 팝업 (운세 문구 목록도 여기에)
hooks/fortune_context.ps1        UserPromptSubmit: 오늘의 운세를 세션당 한 번 Claude에게 전달
hooks/charm.tsx                  프롬프트 위 운세 카드 장신구 (Claude Code mod)
hooks/sounds/ding.mp3            카드를 뒤집을 때 효과음
```

## 바꾸고 싶다면

- **운세 문구**: `hooks/fortune_cards.ps1` 위쪽의 `$messages`·`$codings`·`$colors`·`$keys` 목록을 고치세요.
- **효과음**: `hooks/sounds/ding.mp3`를 원하는 mp3·wav로 바꾸세요. 파일이 없으면 Windows 기본 알림음이 납니다.
- **오늘 다시 뽑기**: `%USERPROFILE%\.claude\lucky-hook\today.json`을 지우고 새 세션을 여세요.

## 제거

```
/plugin uninstall lucky-hook@lucky-hook
```

## 라이선스

MIT
