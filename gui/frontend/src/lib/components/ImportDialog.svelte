<script lang="ts">
  import Dialog from './Dialog.svelte';
  import { createEventDispatcher } from 'svelte';

  export let open = false;
  let uriInput = '';
  let error = '';

  const dispatch = createEventDispatcher<{ import: string }>();

  function handleImport() {
    error = '';
    const trimmed = uriInput.trim();
    if (!trimmed) {
      error = 'Please enter a connection URI';
      return;
    }
    if (!trimmed.startsWith('paqet://')) {
      error = 'URI must start with paqet://';
      return;
    }
    dispatch('import', trimmed);
    uriInput = '';
    open = false;
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      handleImport();
    }
  }
</script>

<Dialog bind:open title="Import Connection URI">
  <div class="import-content">
    <label>
      <span>Paste a paqet:// URI</span>
      <input
        type="text"
        bind:value={uriInput}
        on:keydown={handleKeydown}
        placeholder="paqet://KEY@HOST:PORT?params#Name"
        class="mono"
      />
    </label>
    {#if error}
      <p class="error">{error}</p>
    {/if}
    <div class="actions">
      <button class="secondary" on:click={() => open = false}>Cancel</button>
      <button class="primary" on:click={handleImport}>Import</button>
    </div>
  </div>
</Dialog>

<style>
  .import-content {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  label span {
    display: block;
    margin-bottom: 0.5rem;
    color: var(--text-secondary);
    font-size: 0.85rem;
  }

  label input {
    width: 100%;
  }

  .error {
    color: var(--color-error);
    font-size: 0.85rem;
    margin: 0;
  }

  .actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
  }

  .secondary {
    background: var(--bg-input);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    padding: 0.5rem 1rem;
    border-radius: var(--border-radius);
    cursor: pointer;
  }

  .primary {
    background: var(--accent-color);
    color: var(--text-on-accent);
    border: none;
    padding: 0.5rem 1rem;
    border-radius: var(--border-radius);
    cursor: pointer;
  }

  .primary:hover {
    background: var(--accent-hover);
  }

  .mono {
    font-family: var(--font-mono);
  }
</style>
