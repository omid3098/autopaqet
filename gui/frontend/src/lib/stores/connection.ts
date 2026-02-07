import { writable } from 'svelte/store';

export type ConnectionState = 'idle' | 'starting' | 'connected' | 'error';

export const connectionState = writable<ConnectionState>('idle');
export const lastError = writable<string>('');

// In production with Wails runtime, subscribe to events:
// EventsOn('connection:state', (state: ConnectionState) => {
//   connectionState.set(state);
// });
