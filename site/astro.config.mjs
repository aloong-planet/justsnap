// @ts-check
import { defineConfig } from 'astro/config'

// JustSnap's landing page (landing-page spec). Chinese is the default language at `/`, English is under `/en`.
export default defineConfig({
  site: 'https://justsnap.aloongplanet.com',
  i18n: {
    defaultLocale: 'zh',
    locales: ['zh', 'en'],
    routing: { prefixDefaultLocale: false }
  }
})
