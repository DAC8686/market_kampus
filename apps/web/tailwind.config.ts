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
        mpus: {
          primary: "#B4FFF9",
          accent: "#00C4B4",
          dark: "#00838F",
          bg: "#F5F5F5",
          text: "#242D38",
          muted: "#8F8F8F",
          border: "#D9D9D9",
        },
      },
    },
  },
  plugins: [],
};
export default config;
