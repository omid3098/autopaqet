<script lang="ts">
  import { profiles, activeProfileId, type Profile } from '../lib/stores/profiles';
  import ProfileCard from '../lib/components/ProfileCard.svelte';
  import ImportDialog from '../lib/components/ImportDialog.svelte';
  import ShareDialog from '../lib/components/ShareDialog.svelte';

  let showImport = false;
  let showShare = false;
  let shareURI = '';

  // In production, these call Wails bindings:
  // import { ListProfiles, CreateProfile, DeleteProfile, ImportURI, ExportURI } from '../../wailsjs/go/main/App';

  function handleSelect(e: CustomEvent<string>) {
    activeProfileId.set(e.detail);
  }

  function handleEdit(e: CustomEvent<string>) {
    // Open edit dialog — Phase 3 polish
  }

  function handleDelete(e: CustomEvent<string>) {
    if (confirm('Delete this profile?')) {
      profiles.update(list => list.filter(p => p.id !== e.detail));
      // DeleteProfile(e.detail);
    }
  }

  function handleShare(e: CustomEvent<string>) {
    const profile = $profiles.find(p => p.id === e.detail);
    if (profile) {
      // In production: shareURI = await ExportURI(e.detail);
      shareURI = `paqet://${profile.key}@${profile.host}:${profile.port}#${profile.name}`;
      showShare = true;
    }
  }

  function handleImport(e: CustomEvent<string>) {
    // In production: const profile = await ImportURI(e.detail);
    // Then refresh profiles list
  }

  function addManually() {
    // In production: open a form dialog to create profile manually
    const newProfile: Profile = {
      id: crypto.randomUUID(),
      name: 'New Profile',
      host: '',
      port: 8080,
      key: '',
    };
    profiles.update(list => [...list, newProfile]);
  }
</script>

<div class="profiles-page">
  <div class="header">
    <h2>Profiles</h2>
    <div class="actions">
      <button class="btn-secondary" on:click={() => showImport = true}>
        Import URI
      </button>
      <button class="btn-primary" on:click={addManually}>
        Add Profile
      </button>
    </div>
  </div>

  {#if $profiles.length === 0}
    <div class="empty">
      <p>No profiles yet.</p>
      <p>Import a connection URI or add a profile manually.</p>
    </div>
  {:else}
    <div class="profile-list">
      {#each $profiles as profile (profile.id)}
        <ProfileCard
          {profile}
          isActive={profile.id === $activeProfileId}
          on:select={handleSelect}
          on:edit={handleEdit}
          on:delete={handleDelete}
          on:share={handleShare}
        />
      {/each}
    </div>
  {/if}
</div>

<ImportDialog bind:open={showImport} on:import={handleImport} />
<ShareDialog bind:open={showShare} uri={shareURI} />

<style>
  .profiles-page {
    max-width: 700px;
  }

  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
  }

  .header h2 {
    margin: 0;
  }

  .actions {
    display: flex;
    gap: 0.5rem;
  }

  .btn-primary {
    background: var(--accent-color);
    color: var(--text-on-accent);
    border: none;
    padding: 0.5rem 1rem;
    border-radius: var(--border-radius);
    cursor: pointer;
    font-size: 0.85rem;
  }

  .btn-primary:hover {
    background: var(--accent-hover);
  }

  .btn-secondary {
    background: var(--bg-input);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    padding: 0.5rem 1rem;
    border-radius: var(--border-radius);
    cursor: pointer;
    font-size: 0.85rem;
  }

  .btn-secondary:hover {
    color: var(--text-primary);
  }

  .empty {
    text-align: center;
    padding: 3rem;
    color: var(--text-secondary);
  }

  .empty p {
    margin: 0.25rem 0;
  }

  .profile-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
</style>
