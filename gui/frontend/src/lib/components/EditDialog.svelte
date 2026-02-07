<script lang="ts">
  import Dialog from './Dialog.svelte';
  import type { Profile } from '../stores/profiles';
  import { createEventDispatcher } from 'svelte';

  export let open = false;
  export let profile: Profile | null = null;

  let name = '';
  let host = '';
  let port = 8080;
  let key = '';
  let socksListen = '127.0.0.1:1080';
  let mode = 'fast3';
  let conn = 2;

  const dispatch = createEventDispatcher<{ save: Profile }>();

  let initialized = false;

  $: if (open && !initialized) {
    initialized = true;
    if (profile) {
      name = profile.name;
      host = profile.host;
      port = profile.port;
      key = profile.key;
      socksListen = profile.socks_listen || '127.0.0.1:1080';
      mode = profile.mode || 'fast3';
      conn = profile.conn || 2;
    } else {
      name = '';
      host = '';
      port = 8080;
      key = '';
      socksListen = '127.0.0.1:1080';
      mode = 'fast3';
      conn = 2;
    }
  }

  $: if (!open) {
    initialized = false;
  }

  function handleSave() {
    const saved: Profile = {
      id: profile?.id || crypto.randomUUID(),
      name: name || 'Unnamed Profile',
      host,
      port,
      key,
      socks_listen: socksListen,
      mode,
      conn,
    };
    dispatch('save', saved);
    open = false;
  }
</script>

<Dialog bind:open title={profile ? 'Edit Profile' : 'Add Profile'}>
  <div class="edit-content">
    <label>
      <span>Name</span>
      <input type="text" bind:value={name} placeholder="My Server" />
    </label>
    <label>
      <span>Host</span>
      <input type="text" bind:value={host} placeholder="server.example.com" class="mono" />
    </label>
    <div class="row">
      <label class="flex-1">
        <span>Port</span>
        <input type="number" bind:value={port} min="1" max="65535" />
      </label>
      <label class="flex-1">
        <span>Connections</span>
        <input type="number" bind:value={conn} min="1" max="64" />
      </label>
    </div>
    <label>
      <span>Key</span>
      <input type="text" bind:value={key} placeholder="encryption key" class="mono" />
    </label>
    <div class="row">
      <label class="flex-1">
        <span>SOCKS Listen</span>
        <input type="text" bind:value={socksListen} placeholder="127.0.0.1:1080" class="mono" />
      </label>
      <label class="flex-1">
        <span>Mode</span>
        <select bind:value={mode}>
          <option value="fast3">fast3</option>
          <option value="fast2">fast2</option>
          <option value="fast">fast</option>
          <option value="normal">normal</option>
        </select>
      </label>
    </div>
    <div class="actions">
      <button class="secondary" on:click={() => open = false}>Cancel</button>
      <button class="primary" on:click={handleSave}>Save</button>
    </div>
  </div>
</Dialog>

<style>
  .edit-content {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  label {
    display: flex;
    flex-direction: column;
  }

  label span {
    margin-bottom: 0.35rem;
    color: var(--text-secondary);
    font-size: 0.85rem;
  }

  label input, label select {
    width: 100%;
  }

  .row {
    display: flex;
    gap: 0.75rem;
  }

  .flex-1 {
    flex: 1;
  }

  .actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    margin-top: 0.5rem;
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
