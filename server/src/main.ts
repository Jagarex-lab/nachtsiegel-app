import { createApp } from './transport/app.js';

const app = await createApp({ dbPath: process.env.DB_PATH ?? 'var/orafold.sqlite', host: process.env.HOST ?? '127.0.0.1', port: Number(process.env.PORT ?? 8787), origin: process.env.ORIGIN });
const address = await app.start();
console.log(JSON.stringify({ event: 'prototype.started', url: address.url, prototype: true }));
const telemetry = setInterval(() => console.log(JSON.stringify({ event: 'prototype.metrics', ...app.telemetry(), rss_bytes: process.memoryUsage().rss, cpu_microseconds: process.cpuUsage() })), 60_000);
for (const signal of ['SIGINT', 'SIGTERM'] as const) process.once(signal, async () => { clearInterval(telemetry); await app.close(); process.exit(0); });
