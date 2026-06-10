import { copyFile, mkdir } from 'node:fs/promises';

await mkdir('dist/client/src/client', { recursive: true });
await copyFile('index.html', 'dist/client/index.html');
await copyFile('src/client/styles.css', 'dist/client/src/client/styles.css');
