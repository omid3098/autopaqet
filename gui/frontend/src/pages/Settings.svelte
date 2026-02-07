<script lang="ts">
  import { activeProfile, activeProfileId, profiles } from '../lib/stores/profiles';

  // Settings are per-profile; show the active profile's settings
  let socksListen = '';
  let mode = 'fast3';
  let conn = 2;
  let mtu = 0;
  let block = 'aes';
  let rcvwnd = 0;
  let sndwnd = 0;
  let dshard = 0;
  let pshard = 0;
  let dscp = 0;
  let localFlag = 'PA';
  let remoteFlag = 'PA';
  let smuxbuf = 0;
  let streambuf = 0;
  let tcpbuf = 0;
  let udpbuf = 0;
  let sockbuf = 0;

  let showAdvanced = false;
  let showBuffers = false;
  let showTcp = false;

  $: if ($activeProfile) {
    socksListen = $activeProfile.socks_listen || '127.0.0.1:1080';
    mode = $activeProfile.mode || 'fast3';
    conn = $activeProfile.conn || 2;
    mtu = $activeProfile.mtu || 0;
    block = $activeProfile.block || 'aes';
    rcvwnd = $activeProfile.rcvwnd || 0;
    sndwnd = $activeProfile.sndwnd || 0;
    dshard = $activeProfile.dshard || 0;
    pshard = $activeProfile.pshard || 0;
    dscp = $activeProfile.dscp || 0;
    localFlag = $activeProfile.local_flag || 'PA';
    remoteFlag = $activeProfile.remote_flag || 'PA';
    smuxbuf = $activeProfile.smuxbuf || 0;
    streambuf = $activeProfile.streambuf || 0;
    tcpbuf = $activeProfile.tcpbuf || 0;
    udpbuf = $activeProfile.udpbuf || 0;
    sockbuf = $activeProfile.sockbuf || 0;
  }

  function save() {
    if (!$activeProfileId) return;
    // In production: call UpdateProfile with the new values
    profiles.update(list => list.map(p => {
      if (p.id !== $activeProfileId) return p;
      return {
        ...p,
        socks_listen: socksListen,
        mode, conn, mtu, block, rcvwnd, sndwnd,
        dshard, pshard, dscp, local_flag: localFlag,
        remote_flag: remoteFlag, smuxbuf, streambuf,
        tcpbuf, udpbuf, sockbuf,
      };
    }));
  }
</script>

<div class="settings-page">
  <h2>Settings</h2>

  {#if !$activeProfile}
    <p class="muted">Select a profile on the Connect page to configure its settings.</p>
  {:else}
    <p class="subtitle">Editing: <strong>{$activeProfile.name}</strong></p>

    <section>
      <h3>SOCKS5 Proxy</h3>
      <label>
        <span>Listen Address</span>
        <input type="text" bind:value={socksListen} placeholder="127.0.0.1:1080" />
      </label>
    </section>

    <section>
      <h3>KCP Settings</h3>
      <div class="grid">
        <label>
          <span>Mode</span>
          <select bind:value={mode}>
            <option value="normal">normal</option>
            <option value="fast">fast</option>
            <option value="fast2">fast2</option>
            <option value="fast3">fast3</option>
            <option value="manual">manual</option>
          </select>
        </label>
        <label>
          <span>Connections</span>
          <input type="number" bind:value={conn} min="1" max="16" />
        </label>
        <label>
          <span>Block Cipher</span>
          <select bind:value={block}>
            <option value="aes">aes</option>
            <option value="aes-128">aes-128</option>
            <option value="aes-192">aes-192</option>
            <option value="salsa20">salsa20</option>
            <option value="blowfish">blowfish</option>
            <option value="twofish">twofish</option>
            <option value="cast5">cast5</option>
            <option value="3des">3des</option>
            <option value="tea">tea</option>
            <option value="xtea">xtea</option>
            <option value="sm4">sm4</option>
            <option value="none">none</option>
          </select>
        </label>
      </div>
    </section>

    <section>
      <button class="section-toggle" on:click={() => showAdvanced = !showAdvanced}>
        {showAdvanced ? 'Hide' : 'Show'} Advanced KCP
      </button>
      {#if showAdvanced}
        <div class="grid">
          <label>
            <span>MTU</span>
            <input type="number" bind:value={mtu} min="0" max="9000" placeholder="Default" />
          </label>
          <label>
            <span>Receive Window</span>
            <input type="number" bind:value={rcvwnd} min="0" placeholder="Default" />
          </label>
          <label>
            <span>Send Window</span>
            <input type="number" bind:value={sndwnd} min="0" placeholder="Default" />
          </label>
          <label>
            <span>DSCP</span>
            <input type="number" bind:value={dscp} min="0" max="63" placeholder="0" />
          </label>
          <label>
            <span>Data Shards (FEC)</span>
            <input type="number" bind:value={dshard} min="0" placeholder="0" />
          </label>
          <label>
            <span>Parity Shards (FEC)</span>
            <input type="number" bind:value={pshard} min="0" placeholder="0" />
          </label>
        </div>
      {/if}
    </section>

    <section>
      <button class="section-toggle" on:click={() => showTcp = !showTcp}>
        {showTcp ? 'Hide' : 'Show'} TCP Flags
      </button>
      {#if showTcp}
        <div class="grid">
          <label>
            <span>Local Flag</span>
            <select bind:value={localFlag}>
              <option value="S">S (SYN)</option>
              <option value="PA">PA (PSH+ACK)</option>
              <option value="A">A (ACK)</option>
            </select>
          </label>
          <label>
            <span>Remote Flag</span>
            <select bind:value={remoteFlag}>
              <option value="S">S (SYN)</option>
              <option value="PA">PA (PSH+ACK)</option>
              <option value="A">A (ACK)</option>
            </select>
          </label>
        </div>
      {/if}
    </section>

    <section>
      <button class="section-toggle" on:click={() => showBuffers = !showBuffers}>
        {showBuffers ? 'Hide' : 'Show'} Buffer Sizes
      </button>
      {#if showBuffers}
        <div class="grid">
          <label>
            <span>Smux Buffer</span>
            <input type="number" bind:value={smuxbuf} min="0" placeholder="Default" />
          </label>
          <label>
            <span>Stream Buffer</span>
            <input type="number" bind:value={streambuf} min="0" placeholder="Default" />
          </label>
          <label>
            <span>TCP Buffer</span>
            <input type="number" bind:value={tcpbuf} min="0" placeholder="Default" />
          </label>
          <label>
            <span>UDP Buffer</span>
            <input type="number" bind:value={udpbuf} min="0" placeholder="Default" />
          </label>
          <label>
            <span>Socket Buffer</span>
            <input type="number" bind:value={sockbuf} min="0" placeholder="Default" />
          </label>
        </div>
      {/if}
    </section>

    <button class="btn-save" on:click={save}>Save Settings</button>
  {/if}
</div>

<style>
  .settings-page {
    max-width: 600px;
  }

  h2 {
    margin-top: 0;
  }

  .subtitle {
    color: var(--text-secondary);
    margin-bottom: 1.5rem;
  }

  .muted {
    color: var(--text-secondary);
  }

  section {
    margin-bottom: 1.5rem;
  }

  h3 {
    font-size: 0.9rem;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: 0.75rem;
  }

  .grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
  }

  label {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  label span {
    font-size: 0.8rem;
    color: var(--text-secondary);
  }

  .section-toggle {
    background: none;
    border: none;
    color: var(--accent-color);
    cursor: pointer;
    font-size: 0.85rem;
    padding: 0;
    margin-bottom: 0.75rem;
  }

  .section-toggle:hover {
    text-decoration: underline;
  }

  .btn-save {
    background: var(--accent-color);
    color: var(--text-on-accent);
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: var(--border-radius);
    cursor: pointer;
    font-size: 0.95rem;
    font-weight: 600;
    width: 100%;
  }

  .btn-save:hover {
    background: var(--accent-hover);
  }
</style>
