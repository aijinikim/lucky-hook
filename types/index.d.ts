// 장신구에 그리는 오늘의 운세 카드 (fortune_cards.ps1이 저장한 today.json의 일부)
export type Charm = { card: number; stars: number; color: string; key: string }

declare module 'claude-code' {
  interface PluginState {
    'lucky-hook': { charm: Charm | null }
  }
}
