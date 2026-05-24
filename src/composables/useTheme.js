import { ref, onMounted, watch } from 'vue'

// 主题状态 - 默认设为 true 开启极客霓虹暗黑科技风
const isDarkMode = ref(true)

// 主题管理 composable
export function useTheme() {
  // 从本地存储获取主题设置
  const loadTheme = () => {
    const savedTheme = localStorage.getItem('app-theme')
    if (savedTheme) {
      isDarkMode.value = savedTheme === 'dark'
    } else {
      // 默认首选极客霓虹暗黑科技风！
      isDarkMode.value = true
      localStorage.setItem('app-theme', 'dark')
    }
    applyTheme()
  }

  // 应用主题
  const applyTheme = () => {
    console.log('Applying theme:', isDarkMode.value ? 'dark' : 'light')
    
    // 应用到 document.documentElement (html)
    const root = document.documentElement
    const body = document.body
    
    if (isDarkMode.value) {
      root.classList.add('dark')
      body.classList.add('dark')
      root.setAttribute('data-theme', 'dark')
      // 由 CSS 统一控制背景与渐变，杜绝 JavaScript 强行覆盖
      root.style.backgroundColor = ''
      root.style.color = ''
      body.style.backgroundColor = ''
      body.style.color = ''
    } else {
      root.classList.remove('dark')
      body.classList.remove('dark')
      root.setAttribute('data-theme', 'light')
      // 由 CSS 统一控制背景与渐变，杜绝 JavaScript 强行覆盖
      root.style.backgroundColor = ''
      root.style.color = ''
      body.style.backgroundColor = ''
      body.style.color = ''
    }
    
    console.log('Root classes:', root.className)
    console.log('Body classes:', body.className)
  }

  // 切换主题
  const toggleTheme = () => {
    console.log('Toggle theme called, current:', isDarkMode.value)
    isDarkMode.value = !isDarkMode.value
    console.log('New theme:', isDarkMode.value)
    localStorage.setItem('app-theme', isDarkMode.value ? 'dark' : 'light')
    applyTheme()
  }

  // 设置特定主题
  const setTheme = (theme) => {
    isDarkMode.value = theme === 'dark'
    localStorage.setItem('app-theme', theme)
    applyTheme()
  }

  // 监听系统主题变化
  const watchSystemTheme = () => {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    mediaQuery.addEventListener('change', (e) => {
      // 只有在用户没有手动设置主题时才跟随系统
      if (!localStorage.getItem('app-theme')) {
        isDarkMode.value = e.matches
        applyTheme()
      }
    })
  }

  // 监听主题状态变化
  watch(isDarkMode, (newValue) => {
    console.log('Theme changed to:', newValue ? 'dark' : 'light')
    applyTheme()
    // 更新 Element Plus 主题
    if (newValue) {
      document.body.classList.add('dark')
    } else {
      document.body.classList.remove('dark')
    }
  }, { immediate: true })

  // 初始化
  onMounted(() => {
    console.log('Theme composable mounted')
    loadTheme()
    watchSystemTheme()
  })

  return {
    isDarkMode,
    toggleTheme,
    setTheme,
    loadTheme
  }
}

// 全局主题状态（单例）
let themeInstance = null

export function useGlobalTheme() {
  try {
    if (!themeInstance) {
      themeInstance = useTheme()
    }
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
