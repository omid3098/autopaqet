<script lang="ts">
  import { profiles, activeProfileId, loadProfiles, type Profile } from '../lib/stores/profiles';
  import ProfileCard from '../lib/components/ProfileCard.svelte';
  import ImportDialog from '../lib/components/ImportDialog.svelte';
  import ShareDialog from '../lib/components/ShareDialog.svelte';
  import EditDialog from '../lib/components/EditDialog.svelte';
  import { CreateProfile, UpdateProfile, DeleteProfile, ExportURI, ImportURI } from '../../wailsjs/go/main/App';

  let showImport = false;
  let showShare = false;
  let shareURI = '';
  let showEdit = false;
  let editingProfile: Profile | null = null;

  function handleSelect(e: CustomEvent<string>) {
    activeProfileId.set(e.detail);
  }

  function handleEdit(e: CustomEvent<string>) {
    const p = $profiles.find(p => p.id === e.detail);
    if (p) {
      editingProfile = { ...p };
      showEdit = true;
    }
  }

  async function handleDelete(e: CustomEvent<string>) {
    if (confirm('Delete this profile?')) {
      try {
        await DeleteProfile(e.detail);
        await loadProfiles();
      } catch (err) {
        console.error('Failed to delete profile:', err);
      }
    }
  }

  async function handleShare(e: CustomEvent<string>) {
    try {
      shareURI = await ExportURI(e.detail);
      showShare = true;
    } catch (err) {
      const profile = $profiles.find(p => p.id === e.detail);
      if (profile) {
        shareURI = `paqet://${profile.key}@${profile.host}:${profile.port}#${profile.name}`;
        showShare = true;
      }
    }
  }

  async function handleImport(e: CustomEvent<string>) {
    try {
      await ImportURI(e.detail);
      await loadProfiles();
    } catch (err) {
      console.error('Failed to import URI:', err);
    }
  }

  function addManually() {
    editingProfile = null;
    showEdit = true;
  }

  async function handleSave(e: CustomEvent<Profile>) {
    const saved = e.detail;
    try {
      const existing = $profiles.find(p => p.id === saved.id);
      if (existing) {
        await UpdateProfile(saved as any);
      } else {
        await CreateProfile(saved as any);
      }
      await loadProfiles();
    } catch (err) {
      console.error('Failed to save profile:', err);
    }
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
<EditDialog bind:open={showEdit} profile={editingProfile} on:save={handleSave} />

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
