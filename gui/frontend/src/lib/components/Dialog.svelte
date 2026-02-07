<script lang="ts">
  export let open = false;
  export let title = '';

  function handleBackdrop(e: MouseEvent) {
    if (e.target === e.currentTarget) {
      open = false;
    }
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      open = false;
    }
  }
</script>

<svelte:window on:keydown={handleKeydown} />

{#if open}
  <div class="backdrop" on:click={handleBackdrop} role="dialog" aria-modal="true">
    <div class="dialog">
      <div class="header">
        <h3>{title}</h3>
        <button class="close" on:click={() => open = false}>&times;</button>
      </div>
      <div class="body">
        <slot />
      </div>
    </div>
  </div>
{/if}

<style>
  .backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.6);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 100;
  }

  .dialog {
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    min-width: 400px;
    max-width: 90vw;
    max-height: 80vh;
    box-shadow: var(--shadow-md);
  }

  .header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid var(--border-color);
  }

  .header h3 {
    margin: 0;
    font-size: 1rem;
    color: var(--text-primary);
  }

  .close {
    background: none;
    border: none;
    color: var(--text-secondary);
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0;
    line-height: 1;
  }

  .close:hover {
    color: var(--text-primary);
  }

  .body {
    padding: 1.25rem;
    overflow-y: auto;
  }
</style>
