import { ref, onMounted, onUnmounted, watch } from 'vue'

const isDarkMode = ref(false)
const normalizeTheme = (theme) => ['light', 'dark'].includes(theme) ? theme : 'system'

export function useTheme() {
  let selectedTheme = 'system'
  let mediaQuery = null
  let systemThemeHandler = null

  const systemIsDark = () => {
    if (typeof window.matchMedia !== 'function') return false
    return (mediaQuery || window.matchMedia('(prefers-color-scheme: dark)')).matches
  }

  const applyTheme = () => {
    for (const element of [document.documentElement, document.body]) {
      element.classList.toggle('dark', isDarkMode.value)
      element.setAttribute('data-theme', isDarkMode.value ? 'dark' : 'light')
      element.style.backgroundColor = ''
      element.style.color = ''
    }
  }

  const resolveTheme = () => {
    isDarkMode.value = selectedTheme === 'system' ? systemIsDark() : selectedTheme === 'dark'
    applyTheme()
  }

  const loadTheme = () => {
    try {
      selectedTheme = normalizeTheme(localStorage.getItem('app-theme'))
    } catch {
      selectedTheme = 'system'
    }
    // 没有用户偏好时不写入固定颜色，否则系统主题监听永远不会生效。
    resolveTheme()
  }

  const setTheme = (theme) => {
    selectedTheme = normalizeTheme(theme)
    try {
      localStorage.setItem('app-theme', selectedTheme)
    } catch {
      // 禁用持久存储时仍允许本次会话切换主题。
    }
    resolveTheme()
  }

  const toggleTheme = () => setTheme(isDarkMode.value ? 'light' : 'dark')

  watch(isDarkMode, applyTheme, { immediate: true })

  onMounted(() => {
    if (typeof window.matchMedia === 'function') {
      mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
      systemThemeHandler = (event) => {
        if (selectedTheme === 'system') {
          isDarkMode.value = event.matches
          applyTheme()
        }
      }
      mediaQuery.addEventListener('change', systemThemeHandler)
    }
    loadTheme()
  })

  onUnmounted(() => {
    if (mediaQuery && systemThemeHandler) mediaQuery.removeEventListener('change', systemThemeHandler)
    mediaQuery = null
    systemThemeHandler = null
  })

  return { isDarkMode, toggleTheme, setTheme, loadTheme }
}

let themeInstance = null

export function useGlobalTheme() {
  try {
    if (!themeInstance) themeInstance = useTheme()
    return themeInstance
  } catch (error) {
    console.warn('Global theme initialization failed:', error)
    return {
      isDarkMode: ref(false),
      toggleTheme: () => {},
      setTheme: () => {},
      loadTheme: () => {}
    }
  }
}
