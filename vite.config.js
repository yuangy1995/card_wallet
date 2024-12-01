import { fileURLToPath, URL } from 'node:url'
import { resolve } from 'path'

import { defineConfig } from 'vite'
import AutoImport from 'unplugin-auto-import/vite'
import Components from 'unplugin-vue-components/vite'
import { ElementPlusResolver } from 'unplugin-vue-components/resolvers'
// import obfuscatorBox from 'rollup-plugin-obfuscator';
import vue from '@vitejs/plugin-vue'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    AutoImport({
      resolvers: [ElementPlusResolver()],
    }),
    Components({
      resolvers: [ElementPlusResolver()],
    }),
    // obfuscatorBox({
    //   global: true,
    //   options: {
    //     compact: true,
    //     controlFlowFlattening: true,
    //     controlFlowFlatteningThreshold: 0.75,
    //     numbersToExpressions: true,
    //     simplify: true,
    //     stringArrayShuffle: true,
    //     splitStrings: true,
    //     splitStringsChunkLength: 10,
    //     rotateUnicodeArray: true,
    //     deadCodeInjection: true,
    //     deadCodeInjectionThreshold: 0.4,
    //     debugProtection: false,
    //     debugProtectionInterval: 2000,
    //     disableConsoleOutput: true,
    //     domainLock: [],
    //     identifierNamesGenerator: "hexadecimal",
    //     identifiersPrefix: "",
    //     inputFileName: "",
    //     log: true,
    //     renameGlobals: true,
    //     reservedNames: [],
    //     reservedStrings: [],
    //     seed: 0,
    //     selfDefending: true,
    //     sourceMap: false,
    //     sourceMapBaseUrl: "",
    //     sourceMapFileName: "",
    //     sourceMapMode: "separate",
    //     stringArray: true,
    //     stringArrayEncoding: ["base64"],
    //     stringArrayThreshold: 0.75,
    //     target: "browser",
    //     transformObjectKeys: true,
    //     unicodeEscapeSequence: true,


    //     domainLockRedirectUrl: "about:blank",
    //     forceTransformStrings: [],
    //     identifierNamesCache: null,
    //     identifiersDictionary: [],
    //     ignoreImports: true,
    //     optionsPreset: "default",
    //     renameProperties: false,
    //     renamePropertiesMode: "safe",
    //     sourceMapSourcesMode: "sources-content",

    //     stringArrayCallsTransform: true,
    //     stringArrayCallsTransformThreshold: 0.5,

    //     stringArrayIndexesType: ["hexadecimal-number"],
    //     stringArrayIndexShift: true,
    //     stringArrayRotate: true,
    //     stringArrayWrappersCount: 1,
    //     stringArrayWrappersChainedCalls: true,
    //     stringArrayWrappersParametersMaxCount: 2,
    //     stringArrayWrappersType: "variable",
    //   },

    // }),
    vue(),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    proxy: {
      '/webdav-proxy': {
        target: 'http://192.168.8.175:5005',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/webdav-proxy/, ''),
        configure: (proxy, options) => {
          // 在这里可以直接修改代理请求
          proxy.on('proxyReq', (proxyReq, req, res) => {
            // 删除可能导致问题的头
            proxyReq.removeHeader('Origin');
            proxyReq.removeHeader('Referer');
          });
        },
      }
    }
  }
})
