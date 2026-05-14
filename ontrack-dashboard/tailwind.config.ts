import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        bg: 'var(--bg)',
        surface: 'var(--surface)',
        'surface-2': 'var(--surface-2)',
        accent: 'var(--accent)',
        'accent-dim': 'var(--accent-dim)',
        'text-dim': 'var(--text-dim)',
        'text-muted': 'var(--text-muted)',
      },
    },
  },
  plugins: [],
}
export default config
