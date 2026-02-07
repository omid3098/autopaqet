<script lang="ts">
  import { connectionState } from '../lib/stores/connection';
  import { profiles, activeProfileId, activeProfile } from '../lib/stores/profiles';
  import { diagSteps, resetDiag } from '../lib/stores/diag';
  import StatusBadge from '../lib/components/StatusBadge.svelte';
  import DiagProgress from '../lib/components/DiagProgress.svelte';
  import { Connect, Disconnect, EnableSystemProxy, DisableSystemProxy, CancelConnect } from '../../wailsjs/go/main/App';

  let systemProxy = false;
  let error = '';

  async function handleConnect() {
    if (!$activeProfileId) return;
    error = '';
    resetDiag();
    try {
      await Connect($activeProfileId);
    } catch (e: any) {
      error = e?.message || String(e);
    }
  }

  async function handleDisconnect() {
    error = '';
    try {
      await Disconnect();
    } catch (e: any) {
      error = e?.message || String(e);
    }
    systemProxy = false;
  }

  async function handleCancel() {
    try {
      await CancelConnect();
    } catch (e: any) {
      // ignore cancel errors
    }
  }

  async function handleProxyToggle() {
    error = '';
    try {
      if (systemProxy) {
        await EnableSystemProxy();
      } else {
        await DisableSystemProxy();
      }
    } catch (e: any) {
      error = e?.message || String(e);
      systemProxy = !systemProxy;
    }
  }
</script>

<div class="connect-page">
  <h2>Connect</h2>

  <div class="profile-selector">
    <label>
      <span>Active Profile</span>
      <select bind:value={$activeProfileId}>
        <option value={null}>Select a profile...</option>
        {#each $profiles as p}
          <option value={p.id}>{p.name || 'Unnamed'} ({p.host}:{p.port})</option>
        {/each}
      </select>
    </label>
  </div>

  {#if $activeProfile}
    <div class="connection-info">
      <div class="info-card">
        <h3>Server</h3>
        <p class="mono">{$activeProfile.host}:{$activeProfile.port}</p>
      </div>
      <div class="info-card">
        <h3>Mode</h3>
        <p>{$activeProfile.mode || 'fast3'} / {$activeProfile.conn || 2} conn</p>
      </div>
      <div class="info-card">
        <h3>SOCKS5</h3>
        <p class="mono">{$activeProfile.socks_listen || '127.0.0.1:1080'}</p>
      </div>
    </div>
  {/if}

  {#if error}
    <p class="error-msg">{error}</p>
  {/if}

  {#if $connectionState === 'testing'}
    <DiagProgress steps={$diagSteps} />
  {/if}

  <div class="controls">
    <div class="status-row">
      <StatusBadge state={$connectionState} />
      <span class="state-label">
        {#if $connectionState === 'idle'}Disconnected
        {:else if $connectionState === 'testing'}Testing connection...
        {:else if $connectionState === 'connected'}Connected
        {:else if $connectionState === 'error'}Error
        {/if}
      </span>
    </div>

    {#if $connectionState === 'idle' || $connectionState === 'error'}
      <button
        class="btn-connect"
        on:click={handleConnect}
        disabled={!$activeProfileId}
      >
        {$connectionState === 'error' ? 'Retry' : 'Connect'}
      </button>
    {:else if $connectionState === 'testing'}
      <button class="btn-cancel" on:click={handleCancel}>Cancel</button>
    {:else}
      <button class="btn-disconnect" on:click={handleDisconnect}>
        Disconnect
      </button>
    {/if}

    <label class="checkbox-row">
      <input
        type="checkbox"
        bind:checked={systemProxy}
        on:change={handleProxyToggle}
        disabled={$connectionState !== 'connected'}
      />
      <span>Set as System Proxy</span>
    </label>
  </div>
</div>

<style>
  .connect-page {
    max-width: 600px;
  }

  h2 {
    margin-top: 0;
    margin-bottom: 1.5rem;
  }

  .profile-selector {
    margin-bottom: 1.5rem;
  }

  .profile-selector label span {
    display: block;
    margin-bottom: 0.5rem;
    color: var(--text-secondary);
    font-size: 0.85rem;
  }

  .profile-selector select {
    width: 100%;
    padding: 0.6rem 0.75rem;
  }

  .connection-info {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 0.75rem;
    margin-bottom: 1.5rem;
  }

  .info-card {
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius);
    padding: 0.75rem;
  }

  .info-card h3 {
    margin: 0 0 0.25rem;
    font-size: 0.75rem;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .info-card p {
    margin: 0;
    font-size: 0.9rem;
    color: var(--text-primary);
  }

  .error-msg {
    color: var(--color-error);
    font-size: 0.85rem;
    margin-bottom: 1rem;
    padding: 0.5rem 0.75rem;
    background: rgba(239, 68, 68, 0.1);
    border-radius: var(--border-radius);
  }

  .controls {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .status-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .state-label {
    font-size: 0.9rem;
    color: var(--text-secondary);
  }

  .btn-connect, .btn-disconnect, .btn-cancel {
    width: 100%;
    padding: 0.75rem;
    border: none;
    border-radius: var(--border-radius);
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s;
  }

  .btn-connect {
    background: var(--accent-color);
    color: var(--text-on-accent);
  }

  .btn-connect:hover:not(:disabled) {
    background: var(--accent-hover);
  }

  .btn-connect:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-disconnect {
    background: var(--color-error);
    color: white;
  }

  .btn-disconnect:hover {
    opacity: 0.9;
  }

  .btn-cancel {
    background: var(--bg-secondary);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
  }

  .btn-cancel:hover {
    background: var(--bg-hover);
  }

  .checkbox-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.9rem;
    color: var(--text-secondary);
    cursor: pointer;
  }

  .checkbox-row input:disabled {
    opacity: 0.5;
  }

  .mono {
    font-family: var(--font-mono);
  }
</style>
