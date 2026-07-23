import { defineConfig } from 'tsup';

export default defineConfig({
  entry: ['index.ts', 'abis/index.ts', 'bytecodes/index.ts'],
  format: ['esm', 'cjs'],
  dts: true,
  clean: true,
  outDir: 'dist',
});
