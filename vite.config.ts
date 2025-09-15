import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },
  build: {
    minify: 'terser', // 明确设置 minify 为 terser
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true,
      },
    },
    // 或者使用 esbuild（推荐）
    // minify: 'esbuild',
    // esbuildOptions: {
    //   minify: true,
    // },
  },
  server: {
    host: '0.0.0.0',
    port: 3000,
  },
})