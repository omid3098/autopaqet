<script lang="ts">
  import Dialog from './Dialog.svelte';

  export let open = false;
</script>

<Dialog bind:open title="Npcap Required">
  <div class="npcap-content">
    <p>
      AutoPaqet requires <strong>Npcap</strong> to capture network packets on Windows.
      Npcap is not currently installed on this system.
    </p>
    <p>
      Please download and install Npcap from the official website:
    </p>
    <a href="https://npcap.com" target="_blank" rel="noopener noreferrer" class="download-link">
      https://npcap.com
    </a>
    <p class="note">
      During installation, ensure "WinPcap API-compatible Mode" is checked.
      After installation, restart AutoPaqet.
    </p>
    <div class="actions">
      <button on:click={() => open = false}>Close</button>
    </div>
  </div>
</Dialog>

<style>
  .npcap-content {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  p {
    margin: 0;
    color: var(--text-secondary);
    font-size: 0.9rem;
    line-height: 1.5;
  }

  strong {
    color: var(--text-primary);
  }

  .download-link {
    color: var(--accent-color);
    font-size: 1rem;
    font-weight: 600;
    text-decoration: none;
    padding: 0.75rem;
    background: var(--accent-muted);
    border-radius: var(--border-radius);
    text-align: center;
  }

  .download-link:hover {
    text-decoration: underline;
  }

  .note {
    font-size: 0.8rem;
    font-style: italic;
    color: var(--text-secondary);
  }

  .actions {
    display: flex;
    justify-content: flex-end;
    margin-top: 0.5rem;
  }

  .actions button {
    background: var(--bg-input);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
    padding: 0.5rem 1rem;
    border-radius: var(--border-radius);
    cursor: pointer;
  }

  .actions button:hover {
    background: var(--bg-hover);
  }
</style>
