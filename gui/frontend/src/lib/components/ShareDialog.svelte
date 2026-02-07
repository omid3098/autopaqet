<script lang="ts">
  import Dialog from './Dialog.svelte';

  export let open = false;
  export let uri = '';
  export let qrCodeData: string | null = null;

  let copied = false;

  async function copyURI() {
    try {
      await navigator.clipboard.writeText(uri);
      copied = true;
      setTimeout(() => copied = false, 2000);
    } catch {
      // Fallback
      const input = document.createElement('textarea');
      input.value = uri;
      document.body.appendChild(input);
      input.select();
      document.execCommand('copy');
      document.body.removeChild(input);
      copied = true;
      setTimeout(() => copied = false, 2000);
    }
  }
</script>

<Dialog bind:open title="Share Profile">
  <div class="share-content">
    <label>
      <span>Connection URI</span>
      <div class="uri-row">
        <input type="text" value={uri} readonly class="mono" />
        <button on:click={copyURI}>
          {copied ? 'Copied!' : 'Copy'}
        </button>
      </div>
    </label>

    {#if qrCodeData}
      <div class="qr-code">
        <img src={qrCodeData} alt="QR Code" />
      </div>
    {/if}
  </div>
</Dialog>

<style>
  .share-content {
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

  .uri-row {
    display: flex;
    gap: 0.5rem;
  }

  .uri-row input {
    flex: 1;
    font-size: 0.8rem;
  }

  .uri-row button {
    background: var(--accent-color);
    color: var(--text-on-accent);
    border: none;
    padding: 0.5rem 1rem;
    border-radius: var(--border-radius);
    cursor: pointer;
    font-size: 0.85rem;
    white-space: nowrap;
  }

  .uri-row button:hover {
    background: var(--accent-hover);
  }

  .qr-code {
    display: flex;
    justify-content: center;
    padding: 1rem;
  }

  .qr-code img {
    max-width: 200px;
    border-radius: 8px;
  }

  .mono {
    font-family: var(--font-mono);
  }
</style>
