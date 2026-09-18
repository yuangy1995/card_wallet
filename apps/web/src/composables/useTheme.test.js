// @vitest-environment happy-dom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createApp, h } from 'vue'
import { useTheme } from './useTheme'

describe('theme preferences', () => {
  let app, root, theme, media, listeners, values
  const mount = () => {
    root = document.createElement('div')
    document.body.append(root)
    app = createApp({ setup() { theme = useTheme(); return () => h('div') } })
    app.mount(root)
  }
  const changeSystem = (matches) => {
    media.matches = matches
    listeners.forEach(listener => listener({ matches }))
  }
  beforeEach(() => {
    listeners = new Set()
    values = new Map()
    media = {
      matches: false,
      addEventListener: vi.fn((_, listener) => listeners.add(listener)),
      removeEventListener: vi.fn((_, listener) => listeners.delete(listener))
    }
    vi.stubGlobal('matchMedia', vi.fn(() => media))
    vi.stubGlobal('localStorage', {
      getItem: vi.fn(key => values.get(key) ?? null),
      setItem: vi.fn((key, value) => values.set(key, value))
    })
  })
  afterEach(() => {
    app?.unmount()
    app = null
    root?.remove()
    vi.unstubAllGlobals()
  })
  it('follows system appearance by default without storing a forced color', () => {
    mount()
    expect(theme.isDarkMode.value).toBe(false)
    expect(values.has('app-theme')).toBe(false)
    changeSystem(true)
    expect(theme.isDarkMode.value).toBe(true)
    expect(document.documentElement.classList.contains('dark')).toBe(true)
  })
  it('preserves an existing explicit preference when the system changes', () => {
    values.set('app-theme', 'dark')
    mount()
    changeSystem(false)
    expect(theme.isDarkMode.value).toBe(true)
    theme.toggleTheme()
    expect(values.get('app-theme')).toBe('light')
    changeSystem(true)
    expect(theme.isDarkMode.value).toBe(false)
  })
  it('resolves an explicit system preference and permits restoring it', () => {
    values.set('app-theme', 'system')
    media.matches = true
    mount()
    expect(theme.isDarkMode.value).toBe(true)
    theme.setTheme('light')
    expect(theme.isDarkMode.value).toBe(false)
    theme.setTheme('system')
    expect(theme.isDarkMode.value).toBe(true)
  })
  it('removes the media listener on unmount', () => {
    mount()
    expect(listeners.size).toBe(1)
    app.unmount()
    app = null
    expect(listeners.size).toBe(0)
  })
  it('still allows session-only changes when storage access throws', () => {
    localStorage.getItem.mockImplementation(() => { throw new Error('denied') })
    localStorage.setItem.mockImplementation(() => { throw new Error('denied') })
    mount()
    expect(theme.isDarkMode.value).toBe(false)
    expect(() => theme.toggleTheme()).not.toThrow()
    expect(theme.isDarkMode.value).toBe(true)
  })
})
