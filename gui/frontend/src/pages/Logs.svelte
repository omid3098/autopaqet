<script lang="ts">
  import { filteredLogs, logFilter, autoScroll, clearLogs, type LogLevel } from '../lib/stores/logs';
  import { afterUpdate } from 'svelte';

  let logContainer: HTMLElement;

  afterUpdate(() => {
    if ($autoScroll && logContainer) {
      logContainer.scrollTop = logContainer.scrollHeight;
    }
  });

  async function copyLogs() {
    const text = $filteredLogs.join('\n');
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      // Fallback
    }
  }

  function handleScroll() {
    if (!logContainer) return;
    const { scrollTop, scrollHeight, clientHeight } = logContainer;
    // Auto-disable auto-scroll if user scrolled up
    if (scrollHeight - scrollTop - clientHeight > 50) {
      autoScroll.set(false);
    }
  }
</script>

<div class="logs-page">
  <div class="header">
    <h2>Logs</h2>
    <div class="controls">
      <select bind:value={$logFilter}>
        <option value="all">All</option>
        <option value="info">Info+</option>
        <option value="warn">Warn+</option>
        <option value="error">Errors</option>
      </select>
      <label class="auto-scroll">
        <input type="checkbox" bind:checked={$autoScroll} />
        Auto-scroll
      </label>
      <button on:click={copyLogs}>Copy</button>
      <button on:click={clearLogs}>Clear</button>
    </div>
  </div>

  <div
    class="log-viewer"
    bind:this={logContainer}
    on:scroll={handleScroll}
  >
    {#if $filteredLogs.length === 0}
      <p class="empty">No log output yet. Connect to start seeing logs.</p>
    {:else}
      {#each $filteredLogs as line}
        <div class="log-line" class:error={line.includes('[ERROR]') || line.includes('error')} class:warn={line.includes('[WARN]') || line.includes('warn')}>
          {line}
        </div>
      {/each}
    {/if}
  </div>
</div>

<style>
  .logs-page {
    display: flex;
    flex-direction: column;
    height: 100%;
  }

  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
    flex-shrink: 0;
  }

  h2 {
    margin: 0;
  }

  .controls {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .controls select {
    padding: 0.35rem 0.5rem;
    font-size: 0.8rem;
  }

  .controls button {
    background: var(--bg-input);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    padding: 0.35rem 0.75rem;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.8rem;
  }

  .controls button:hover {
    color: var(--text-primary);
  }

  .auto-scroll {
    display: flex;
    align-items: center;
    gap: 0.25rem;
    font-size: 0.8rem;
    color: var(--text-secondary);
    cursor: pointer;
  }

  .log-viewer {
    flex: 1;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius);
    padding: 0.75rem;
    overflow-y: auto;
    font-family: var(--font-mono);
    font-size: 0.8rem;
    line-height: 1.6;
    min-height: 300px;
  }

  .empty {
    color: var(--text-secondary);
    text-align: center;
    padding: 2rem;
  }

  .log-line {
    white-space: pre-wrap;
    word-break: break-all;
    color: var(--text-primary);
  }

  .log-line.error {
    color: var(--color-error);
  }

  .log-line.warn {
    color: var(--color-starting);
  }
</style>
