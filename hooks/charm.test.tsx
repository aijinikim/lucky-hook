import { expect, test } from 'claude-code/testing'

const BAND = {
  plugin: 'lucky-hook',
  component: 'AbovePrompt',
  props: {
    hasSurvey: false,
    isWorking: false,
    maxRows: 20,
    bodyColumns: 80,
    scroll: { offset: 0, bodyRows: 19 },
    view: {},
  },
} as const

const CARD = { card: 2, stars: 3, color: '라벤더', key: 'Ctrl+C' }

test('오늘 고른 카드가 장신구로 그려진다, 모든 표면에서', async ($, on) => {
  on('state.get', () => ({ value: { value: CARD, version: 1 } }))

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...BAND, surface })

    expect((await ui.find({ type: 'Text', text: /No\./ }))?.text).toBe('No.2')
    expect((await ui.find({ type: 'Text', text: /★/ }))?.text).toBe('☁  ★★★☆☆')
    expect((await ui.find({ type: 'Text', text: /Ctrl/ }))?.text).toBe('색 라벤더 · 키 Ctrl+C')
    await ui.unmount()
  }
})

test('고른 카드가 없으면 엔진에 밴드를 양보한다', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })

  expect((await ui.find({ type: 'Text' }))?.text).toBe('engine')
  await ui.unmount()
})

test('설문이 밴드를 쓰는 동안에는 그리지 않는다', async ($, on) => {
  on('state.get', () => ({ value: { value: CARD, version: 1 } }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>survey</Text>
  })

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal', props: { ...BAND.props, hasSurvey: true } })

  expect((await ui.find({ type: 'Text' }))?.text).toBe('survey')
  await ui.unmount()
})
