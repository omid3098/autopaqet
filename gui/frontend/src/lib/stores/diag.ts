import { writable } from 'svelte/store';
import { EventsOn } from '../../../wailsjs/runtime/runtime';

export interface DiagStep {
  id: string;
  status: 'running' | 'pass' | 'fail' | 'skip' | 'warn';
  message: string;
  detail?: string;
}

export const diagSteps = writable<DiagStep[]>([]);

export function resetDiag() {
  diagSteps.set([]);
}

EventsOn('diag:step', (step: DiagStep) => {
  diagSteps.update(steps => {
    const idx = steps.findIndex(s => s.id === step.id);
    if (idx >= 0) {
      const updated = [...steps];
      updated[idx] = step;
      return updated;
    }
    return [...steps, step];
  });
});
