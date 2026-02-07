<script lang="ts">
  import { onMount } from 'svelte';

  export let message = '';
  export let type: 'info' | 'success' | 'error' = 'info';
  export let duration = 3000;
  export let visible = false;

  let timeout: ReturnType<typeof setTimeout>;

  $: if (visible && duration > 0) {
    clearTimeout(timeout);
    timeout = setTimeout(() => {
      visible = false;
    }, duration);
  }

  onMount(() => {
    return () => clearTimeout(timeout);
  });
</script>

{#if visible}
  <div class="toast {type}" role="alert">
    <span>{message}</span>
    <button on:click={() => visible = false}>&times;</button>
  </div>
{/if}

<style>
  .toast {
    position: fixed;
    bottom: 1.5rem;
    right: 1.5rem;
    padding: 0.75rem 1rem;
    border-radius: 8px;
    display: flex;
    align-items: center;
    gap: 0.75rem;
    z-index: 200;
    box-shadow: var(--shadow-md);
    font-size: 0.9rem;
    animation: slideIn 0.2s ease-out;
  }

  .info {
    background: var(--bg-tertiary);
    border: 1px solid var(--accent-color);
    color: var(--text-primary);
  }

  .success {
    background: rgba(34, 197, 94, 0.15);
    border: 1px solid var(--color-connected);
    color: var(--color-connected);
  }

  .error {
    background: rgba(239, 68, 68, 0.15);
    border: 1px solid var(--color-error);
    color: var(--color-error);
  }

  button {
    background: none;
    border: none;
    color: inherit;
    font-size: 1.25rem;
    cursor: pointer;
    padding: 0;
    opacity: 0.7;
  }

  button:hover {
    opacity: 1;
  }

  @keyframes slideIn {
    from { transform: translateY(1rem); opacity: 0; }
    to { transform: translateY(0); opacity: 1; }
  }
</style>
