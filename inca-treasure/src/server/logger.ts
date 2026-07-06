/**
 * 轻量结构化日志（零依赖）。
 *
 * 输出单行 JSON，便于生产环境的日志采集系统（如 Loki / CloudWatch / ELK）解析。
 * 通过 LOG_LEVEL 环境变量控制级别（debug < info < warn < error），默认 info。
 */

type LogLevel = 'debug' | 'info' | 'warn' | 'error';

const levelWeight: Record<LogLevel, number> = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40,
};

const activeLevel: LogLevel = (() => {
  const raw = String(process.env.LOG_LEVEL ?? 'info').toLowerCase();
  if (raw === 'debug' || raw === 'info' || raw === 'warn' || raw === 'error') return raw;
  return 'info';
})();

function emit(level: LogLevel, event: string, fields?: Record<string, unknown>): void {
  if (levelWeight[level] < levelWeight[activeLevel]) return;
  const entry = {
    ts: new Date().toISOString(),
    level,
    event,
    ...fields,
  };
  const line = JSON.stringify(entry);
  if (level === 'error') {
    process.stderr.write(line + '\n');
  } else {
    process.stdout.write(line + '\n');
  }
}

export const logger = {
  debug: (event: string, fields?: Record<string, unknown>) => emit('debug', event, fields),
  info: (event: string, fields?: Record<string, unknown>) => emit('info', event, fields),
  warn: (event: string, fields?: Record<string, unknown>) => emit('warn', event, fields),
  error: (event: string, fields?: Record<string, unknown>) => emit('error', event, fields),
};
