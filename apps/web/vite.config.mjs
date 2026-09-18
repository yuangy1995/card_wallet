import { fileURLToPath, URL } from 'node:url'
import { resolve } from 'path'

import { defineConfig, loadEnv } from 'vite'
import AutoImport from 'unplugin-auto-import/vite'
import Components from 'unplugin-vue-components/vite'
import { ElementPlusResolver } from 'unplugin-vue-components/resolvers'
import vue from '@vitejs/plugin-vue'

const isVueUsePureAnnotationWarning = (warning) => {
  const id = String(warning?.id || '')
  const message = String(warning?.message || '')
  return warning?.code === 'INVALID_ANNOTATION' &&
    /@vueuse[+/]core/.test(id) &&
    message.includes('#__PURE__')
}

// https://vitejs.dev/config/
export default defineConfig(({ command, mode }) => {
  // 加载环境变量
  const env = loadEnv(mode, process.cwd())
  // Dev 使用根路径，Build 优先使用 VITE_BASE；否则使用相对路径，便于任意静态路径部署
  let baseUrl = '/'
  if (command === 'build') {
    const rawBase = (env.VITE_BASE || '').trim()
    if (rawBase) {
      baseUrl = rawBase.endsWith('/') ? rawBase : `${rawBase}/`
    } else {
      baseUrl = './'
    }
  }

  return {
    base: baseUrl,
    test: { server: { deps: { inline: ['element-plus'] } } },
    plugins: [
      AutoImport({
        resolvers: [ElementPlusResolver()],
      }),
      Components({
        resolvers: [ElementPlusResolver()],
      }),
      vue(),
    ],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url))
      }
    },
    css: {
      preprocessorOptions: {
        scss: {
          silenceDeprecations: ['legacy-js-api']
        }
      }
    },
    build: {
      reportCompressedSize: true,
      manifest: true,
      chunkSizeWarningLimit: 1500,
      minify: 'terser',
      terserOptions: {
        compress: {
          drop_console: true,
          drop_debugger: true
        },
        format: {
          comments: false
        },
        mangle: {
          keep_fnames: true // 保持函数名不变，避免影响一些动态引用
        }
      },
      rollupOptions: {
        onwarn(warning, warn) {
          if (isVueUsePureAnnotationWarning(warning)) {
            return
          }
          warn(warning)
        },
        output: {
          manualChunks(id) {
            // 只隔离体积较大的可选依赖，其余由 Rollup 按使用关系拆分。
            if (id.includes('node_modules')) {
              if (id.includes('echarts')) {
                return 'echarts';
              } else if (id.includes('webdav')) {
                return 'webdav';
              } else if (id.includes('crypto-js')) {
                return 'crypto';
              } else if (id.includes('zrender')) {
                return 'echarts';
              }
              // Let Rollup keep unrelated dependencies out of the initial shared chunk.
              return undefined
            }
          },
          chunkFileNames: 'assets/js/[name]-[hash].js',
          entryFileNames: 'assets/js/[name]-[hash].js',
          assetFileNames: 'assets/[ext]/[name]-[hash].[ext]'
        }
      }
    }
  }
})
