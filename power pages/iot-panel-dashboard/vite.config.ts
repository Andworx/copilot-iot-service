import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')

  return {
    plugins: [react()],
    build: {
      outDir: 'dist',
    },
    server: {
      proxy: {
        // Proxy Dataverse OData calls to the org URL in local dev
        '/api/data': {
          target: env.VITE_DATAVERSE_URL ?? '',
          changeOrigin: true,
          secure: true,
        },
      },
    },
  }
})
