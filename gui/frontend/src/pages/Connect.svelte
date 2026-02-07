<script lang="ts">
  import { connectionState } from '../lib/stores/connection';
  import { profiles, activeProfileId, activeProfile } from '../lib/stores/profiles';
  import StatusBadge from '../lib/components/StatusBadge.svelte';

  let systemProxy = false;

  // In production, these call Wails bindings:
  // import { Connect, Disconnect, DetectNetwork } from '../../wailsjs/go/main/App';

  function handleConnect() {
    if (!$activeProfileId) return;
    // Connect($activeProfileId);
    connectionState.set('starting');
    // Simulated for dev
    setTimeout(() => connectionState.set('connected'), 1000);
  }

  function handleDisconnect() {
    // Disconnect();
    connectionState.set('idle');
    systemProxy = false;
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

  <div class="controls">
    <div class="status-row">
      <StatusBadge state={$connectionState} />
      <span class="state-label">
        {#if $connectionState === 'idle'}Disconnected
        {:else if $connectionState === 'starting'}Connecting...
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
        Connect
      </button>
    {:else if $connectionState === 'starting'}
      <button class="btn-connect" disabled>Connecting...</button>
    {:else}
      <button class="btn-disconnect" on:click={handleDisconnect}>
        Disconnect
      </button>
    {/if}

    <label class="checkbox-row">
      <input
        type="checkbox"
        bind:checked={systemProxy}
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

  .btn-connect, .btn-disconnect {
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
