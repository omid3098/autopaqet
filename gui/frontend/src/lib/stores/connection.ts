import { writable } from 'svelte/store';
import { EventsOn } from '../../../wailsjs/runtime/runtime';

export type ConnectionState = 'idle' | 'testing' | 'connected' | 'error';

export const connectionState = writable<ConnectionState>('idle');
export const lastError = writable<string>('');

EventsOn('connection:state', (state: ConnectionState) => {
  connectionState.set(state);
});
