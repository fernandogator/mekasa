import type { Config } from 'tailwindcss';

const token = (name: string) => `rgb(var(--${name}) / <alpha-value>)`;

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    colors: {
      transparent: 'transparent',
      current: 'currentColor',
      brand: token('color-brand'),
      'brand-muted': token('color-brand-muted'),
      surface: token('color-surface'),
      elevated: token('color-surface-elevated'),
      text: token('color-text'),
      muted: token('color-text-muted'),
      accent: token('color-accent'),
      'accent-text': token('color-accent-text'),
      'on-accent': token('color-on-accent'),
      'on-brand': token('color-on-brand'),
      'on-brand-muted': token('color-on-brand-muted'),
      danger: token('color-danger'),
      success: token('color-success'),
      warning: token('color-warning'),
      'warning-tint': token('color-warning-tint'),
      'success-tint': token('color-success-tint'),
      border: token('color-border'),
      line: token('color-line'),
      scrim: token('color-scrim'),
    },
    fontFamily: {
      sans: ['var(--font-sans)'],
    },
    borderRadius: {
      none: '0',
      sm: 'var(--radius-sm)',
      DEFAULT: 'var(--radius-md)',
      md: 'var(--radius-md)',
      lg: 'var(--radius-lg)',
      xl: 'var(--radius-xl)',
      full: '9999px',
    },
    boxShadow: {
      none: 'none',
      card: 'var(--shadow-card)',
      raised: 'var(--shadow-raised)',
      focus: 'var(--shadow-focus)',
    },
    extend: {},
  },
  plugins: [],
} satisfies Config;
