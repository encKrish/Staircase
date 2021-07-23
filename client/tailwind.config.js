const colors = require('tailwindcss/colors')

module.exports = {
  purge: ['./src/**/*.{js,jsx,ts,tsx}', './public/index.html'],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {
      colors: {
        gray: colors.gray,
        teal: colors.teal,
        orange: colors.orange,
        rose: colors.rose,
        pink: colors.pink,
        purple: colors.purple,
        indigo: colors.indigo,
      }
    },
  },
  variants: {
    extend: {},
  },
  plugins: [],
}
