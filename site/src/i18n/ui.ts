// Every string of the page, in both languages (landing-page::CON-002). This dictionary is the site's own, separate
// from the app's. The Chinese copy is the source; the wording is the confirmed prototype's.
export const LOCALES = ['zh', 'en'] as const
export type Locale = (typeof LOCALES)[number]

const zh = {
  htmlLang: 'zh-Hans',
  title: '随译 JustSnap：截一块屏幕，直接提取文字或翻译',
  description: '随译（JustSnap）是 macOS 菜单栏里的截图工具：框选任意区域，几秒内拿到提取的文字或译文。用你自己的模型服务商。',
  brand: '随译 JustSnap',
  nav: { label: '主导航', features: '功能', download: '下载与安装', github: 'GitHub' },
  langLabel: '语言',
  breadcrumbLabel: '面包屑导航',
  hero: {
    title: '截一块屏幕，直接提取文字或翻译',
    lead: '随译（JustSnap）是 macOS 菜单栏里的截图工具：框选任意区域，几秒内拿到提取的文字或译文。用你自己的模型服务商。',
    shotAlt: '随译的截图选区：按下快捷键后屏幕冻结，框选要处理的区域'
  },
  platform: 'macOS 14.4 或更高 · Apple 芯片',
  features: { title: '一个快捷键，从屏幕到文字', sub: '不做标注，也不先过传统 OCR：原图直接交给视觉模型。', count: '{n} / {total}' },
  steps: [
    { title: '选取屏幕区域', text: '按下快捷键，屏幕在那一刻冻结。点一下就能吸附窗口、菜单栏图标或整块显示器，也可以拖出任意矩形。', alt: '随译选取屏幕区域' },
    { title: '提取文字', text: '一次请求返回结构化的 Markdown，边生成边显示在结果框里，一键复制。', alt: '随译的文字提取结果' },
    { title: '翻译', text: '原文与译文对照显示，目标语言随时可换，不必先提取再翻译。', alt: '随译的截图翻译结果' },
    { title: '粘贴图片或文字', text: '剪贴板里的图片或文字，同样可以提取或翻译，结果显示在独立的浮动结果框里。', alt: '随译的粘贴操作' },
    { title: '历史与重试', text: '每次操作都留有记录：原图、结果和状态。失败或不满意时，直接在原记录上重试。', alt: '随译的历史记录' },
    { title: '用自己的模型服务商', text: 'OpenAI、Gemini、DeepSeek 等，用你自己的 API Key。密钥保存在 macOS 钥匙串，截图只发给你选的那一家。', alt: '随译的模型服务商设置' }
  ],
  download: {
    title: '下载与安装',
    formal: { hero: '下载随译 {version}', every: '在 GitHub 查看所有版本', line: '当前版本 {version}', download: '下载', github: 'GitHub' },
    list: { hero: '从 GitHub 下载随译', line: '暂时无法读取版本信息，请前往 GitHub 下载', button: '前往 GitHub 下载' }
  },
  install: {
    title: '三步装好',
    steps: [
      { title: '下载 DMG', text: '点上方的下载按钮，得到 DMG 安装包。' },
      { title: '拖进“应用程序”', text: '打开 DMG，把随译拖进“应用程序”文件夹。' },
      {
        title: '打开并授权',
        text: 'macOS 会提示 Apple 已检查过它没有恶意软件，点“打开”即可。首次启动会引导你授予屏幕录制权限，并添加模型服务商的 API Key；有新版本时，菜单栏面板会出现更新提示。'
      }
    ]
  },
  footer: { github: 'GitHub', releases: '发布列表', copyright: '© aloong planet' }
}

type Shape<T> = T extends string ? string : T extends readonly (infer U)[] ? Shape<U>[] : { [K in keyof T]: Shape<T[K]> }

const en: Shape<typeof zh> = {
  htmlLang: 'en',
  title: 'JustSnap: snap any part of your screen, get the text or the translation',
  description:
    'JustSnap lives in your Mac\'s menu bar. Select any region, and seconds later a vision model hands back the text or the translation. Bring your own provider.',
  brand: 'JustSnap',
  nav: { label: 'Main', features: 'Features', download: 'Download', github: 'GitHub' },
  langLabel: 'Language',
  breadcrumbLabel: 'Breadcrumb',
  hero: {
    title: 'Snap any part of your screen. Get the text or the translation.',
    lead: 'JustSnap lives in your Mac\'s menu bar. Select any region, and seconds later a vision model hands back the text or the translation. Bring your own provider.',
    shotAlt: 'JustSnap\'s region selection: the screen freezes on the shortcut and a region is dragged out'
  },
  platform: 'macOS 14.4 or later · Apple silicon',
  features: { title: 'From screen to text in one shortcut', sub: 'No annotation tools, no classic OCR step: the original image goes straight to a vision model.', count: '{n} / {total}' },
  steps: [
    { title: 'Select a region of the screen', text: 'Press the shortcut and the screen freezes on the spot. One click snaps to a window, a menu bar icon or a whole display, or drag out any rectangle.', alt: 'JustSnap selecting a region of the screen' },
    { title: 'Extract the text', text: 'One request returns structured Markdown, streamed into the result box as it is written, and copied in one click.', alt: 'JustSnap\'s text extraction result' },
    { title: 'Translate', text: 'Original and translation side by side, with the target language one click away. No need to extract first.', alt: 'JustSnap\'s screenshot translation result' },
    { title: 'Paste an image or text', text: 'An image or text from your clipboard can be extracted or translated just the same, in a floating result box of its own.', alt: 'JustSnap\'s paste action' },
    { title: 'History and retry', text: 'Every operation leaves a record: the original image, the result and its status. If it fails or you want another go, retry on the same record.', alt: 'JustSnap\'s history' },
    { title: 'Bring your own provider', text: 'OpenAI, Gemini, DeepSeek and more, with your own API key. Keys stay in the macOS Keychain, and the screenshot goes only to the provider you pick.', alt: 'JustSnap\'s provider settings' }
  ],
  download: {
    title: 'Download and install',
    formal: { hero: 'Download JustSnap {version}', every: 'See every version on GitHub', line: 'Current version {version}', download: 'Download', github: 'GitHub' },
    list: { hero: 'Download JustSnap from GitHub', line: 'Version details can\'t be loaded right now — download from GitHub', button: 'Download from GitHub' }
  },
  install: {
    title: 'Installed in three steps',
    steps: [
      { title: 'Download the DMG', text: 'Use the download button above to get the installer.' },
      { title: 'Drag it to Applications', text: 'Open the DMG and drag JustSnap into the Applications folder.' },
      {
        title: 'Open it and allow access',
        text: 'macOS will say Apple checked it for malicious software and found none; click Open. The first launch walks you through Screen Recording permission and adding a provider\'s API key. When a new version is out, the menu bar panel shows an update notice.'
      }
    ]
  },
  footer: { github: 'GitHub', releases: 'Releases', copyright: '© aloong planet' }
}

export const ui: Record<Locale, typeof zh> = { zh, en }

/** Each language's page, and how its toggle is written (the same in both pages, so a visitor finds it by its own name) */
export const PAGE_PATH: Record<Locale, string> = { zh: '/', en: '/en/' }
export const LANGUAGE_NAME: Record<Locale, string> = { zh: '中文', en: 'EN' }
/** The author's homepage, which lists the other apps and tools; the header's breadcrumb leads back to it, under the
 * same name on both pages (landing-page::REQ-009/AC-01) */
export const HOMEPAGE = { name: 'aloong planet', url: 'https://aloongplanet.com/' }
