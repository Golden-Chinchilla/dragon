import js from "@eslint/js";
import globals from "globals";
export default [
  { ignores: ["dist/**"] },
  js.configs.recommended,
  { files: ["tests/**"], languageOptions: { globals: globals.node } },
  {
    languageOptions: { globals: globals.browser },
    rules: { "no-unused-vars": ["error", { argsIgnorePattern: "^_" }] },
  },
];
