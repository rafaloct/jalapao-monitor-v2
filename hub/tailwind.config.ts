import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        jalapao: {
          terra: '#FBE9E7',
          primary: '#D87D4A',
          secondary: '#00ACC1',
          accent: '#FBC02D',
          text: '#3E2723',
          error: '#D32F2F',
          cardQueue: '#FFCCBC',
          cardWater: '#B2EBF2',
          border: '#D7CCC8',
        }
      },
      backgroundImage: {
        "gradient-radial": "radial-gradient(var(--tw-gradient-stops))",
        "gradient-conic":
          "conic-gradient(from 180deg at 50% 50%, var(--tw-gradient-stops))",
      },
    },
  },
  plugins: [require('@tailwindcss/typography')],
};
export default config;
