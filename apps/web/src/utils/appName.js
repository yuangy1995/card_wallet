export const getAppName = (language = globalThis.navigator?.language) => {
  return language?.toLowerCase().startsWith('zh') ? '卡包' : 'Card Wallet'
}
