import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Charm } from '../types'

// 오늘 뽑은 운세 카드를 프롬프트 바로 위 오른쪽에 작은 카드로 띄워 둔다.
// 카드는 SessionStart 훅의 팝업(fortune_cards.ps1)이 ~/.claude/lucky-hook/today.json에 저장한 것을 읽는다.

const charm = atom({ plugin: 'lucky-hook', key: 'charm' } as const, null)

const CORAL = '#D97757'
const REFRESH_MS = 10_000  // 팝업에서 카드를 고르면 이 간격 안에 나타나고, 자정이 지나면 사라진다

// 총운에 따라 카드 그림: 5 ☀, 4 ✿, 3 ☁, 2 ☂ — fortune_cards.ps1의 Get-Glyph와 같다
const GLYPHS: Record<number, string> = { 5: '☀', 4: '✿', 3: '☁', 2: '☂' }

const stars = (n: number) => '★'.repeat(n) + '☆'.repeat(Math.max(0, 5 - n))

// fortune_cards.ps1과 같은 yyyy-MM-dd (로컬 날짜)
const localDate = (ms: number) => {
  const d = new Date(ms)
  const pad = (n: number) => String(n).padStart(2, '0')

  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

// today.json을 읽어 장신구 값을 맞춘다. 파일이 없거나 날짜가 지났으면 null
const refresh = async ($: EngineInterface) => {
  let next: Charm | null = null

  try {
    const home = await $.env.get('USERPROFILE')
    const text = await $.fs.read(`${home}/.claude/lucky-hook/today.json`)
    const f = JSON.parse(text.replace(/^﻿/, ''))

    if (f.date === localDate(await $.clock.now())) {
      next = { card: f.card, stars: f.stars, color: f.color, key: f.key }
    }
  } catch {}

  const prev = await read($, charm)

  if (JSON.stringify(prev) !== JSON.stringify(next)) {
    await update($, charm, () => next)
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await refresh($)
    $.clock.every(REFRESH_MS, () => void refresh($))

    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const c = await read($, charm)

    // 설문이 밴드를 쓰는 중이거나 오늘 고른 카드가 없으면 양보한다
    if (e.props.hasSurvey || c === null) {
      return next(e)
    }

    const { Box, Text } = $.ui.resolve(e)

    return (
      <Box justifyContent="flex-end">
        <Box flexDirection="column" borderStyle="round" borderColor={CORAL} paddingX={1}>
          <Text dimColor>{`No.${c.card}`}</Text>
          <Text color={CORAL}>{`${GLYPHS[c.stars] ?? '★'}  ${stars(c.stars)}`}</Text>
          <Text>{`색 ${c.color} · 키 ${c.key}`}</Text>
        </Box>
      </Box>
    )
  })
}
