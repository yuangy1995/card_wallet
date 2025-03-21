import { fileURLToPath, URL } from 'node:url'
import { resolve } from 'path'

import { defineConfig, loadEnv } from 'vite'
import AutoImport from 'unplugin-auto-import/vite'
import Components from 'unplugin-vue-components/vite'
import { ElementPlusResolver } from 'unplugin-vue-components/resolvers'
import vue from '@vitejs/plugin-vue'
import { visualizer } from 'rollup-plugin-visualizer'

// https://vitejs.dev/config/
export default defineConfig(({ command, mode }) => {
  // 加载环境变量
  const env = loadEnv(mode, process.cwd())
  // 根据环境变量决定是否使用'/card/'前缀
  const baseUrl = env.VITE_USE_CARD_PREFIX === 'true' ? '/card/' : '/'
  
  return {
    base: baseUrl,
    plugins: [
      AutoImport({
        resolvers: [ElementPlusResolver()],
      }),
      Components({
        resolvers: [ElementPlusResolver()],
      }),
      vue(),
      visualizer({
        open: true,
        gzipSize: true,
        brotliSize: true,
      }),
    ],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url))
      }
    },
    build: {
      reportCompressedSize: true,
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
        output: {
          manualChunks(id) {
            // 创建一个 vendor 包含所有第三方模块
            if (id.includes('node_modules')) {
              if (id.includes('element-plus')) {
                return 'element-plus';
              } else if (id.includes('echarts')) {
                return 'echarts';
              } else if (id.includes('webdav')) {
                return 'webdav';
              } else if (id.includes('crypto-js')) {
                return 'crypto';
              } else {
                return 'vendor';
              }
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
