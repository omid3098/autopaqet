<script lang="ts">
  import { connectionState, type ConnectionState } from '../stores/connection';
  import StatusBadge from './StatusBadge.svelte';

  export let currentPage: string;

  const navItems = [
    { id: 'connect', label: 'Connect' },
    { id: 'profiles', label: 'Profiles' },
    { id: 'settings', label: 'Settings' },
    { id: 'logs', label: 'Logs' },
  ];

  const stateLabels: Record<ConnectionState, string> = {
    idle: 'Disconnected',
    starting: 'Connecting...',
    connected: 'Connected',
    error: 'Error',
  };
</script>

<aside class="sidebar">
  <div class="logo">
    <h1>AutoPaqet</h1>
  </div>
  <nav>
    {#each navItems as item}
      <button
        class:active={currentPage === item.id}
        on:click={() => currentPage = item.id}
      >
        {item.label}
      </button>
    {/each}
  </nav>
  <div class="status">
    <StatusBadge state={$connectionState} />
    <span>{stateLabels[$connectionState]}</span>
  </div>
</aside>

<style>
  .sidebar {
    width: 220px;
    background: var(--bg-secondary);
    display: flex;
    flex-direction: column;
    border-right: 1px solid var(--border-color);
    flex-shrink: 0;
  }

  .logo {
    padding: 1.5rem 1rem;
    border-bottom: 1px solid var(--border-color);
  }

  .logo h1 {
    margin: 0;
    font-size: 1.25rem;
    color: var(--accent-color);
  }

  nav {
    flex: 1;
    display: flex;
    flex-direction: column;
    padding: 0.5rem;
    gap: 0.25rem;
  }

  nav button {
    background: none;
    border: none;
    color: var(--text-secondary);
    padding: 0.75rem 1rem;
    text-align: left;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.9rem;
    transition: background 0.15s, color 0.15s;
  }

  nav button:hover {
    background: var(--bg-hover);
    color: var(--text-primary);
  }

  nav button.active {
    background: var(--accent-color);
    color: var(--text-on-accent);
  }

  .status {
    padding: 1rem;
    border-top: 1px solid var(--border-color);
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.85rem;
    color: var(--text-secondary);
  }
</style>
