import { writable, derived } from 'svelte/store';
import { EventsOn } from '../../../wailsjs/runtime/runtime';

export type LogLevel = 'all' | 'info' | 'warn' | 'error';

export const logLines = writable<string[]>([]);
export const logFilter = writable<LogLevel>('all');
export const autoScroll = writable<boolean>(true);

export const filteredLogs = derived(
  [logLines, logFilter],
  ([$logLines, $logFilter]) => {
    if ($logFilter === 'all') return $logLines;
    return $logLines.filter(line => {
      const lower = line.toLowerCase();
      switch ($logFilter) {
        case 'error': return lower.includes('error') || lower.includes('[error]');
        case 'warn': return lower.includes('warn') || lower.includes('[warn]') || lower.includes('error') || lower.includes('[error]');
        case 'info': return true;
        default: return true;
      }
    });
  }
);

export function addLogLine(line: string) {
  logLines.update(lines => {
    const newLines = [...lines, line];
    if (newLines.length > 5000) {
      return newLines.slice(-5000);
    }
    return newLines;
  });
}

export function clearLogs() {
  logLines.set([]);
}

EventsOn('log:line', (line: string) => addLogLine(line));
