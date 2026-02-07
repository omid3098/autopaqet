<script lang="ts">
  import type { Profile } from '../stores/profiles';
  import { createEventDispatcher } from 'svelte';

  export let profile: Profile;
  export let isActive = false;

  const dispatch = createEventDispatcher<{
    select: string;
    edit: string;
    delete: string;
    share: string;
  }>();
</script>

<div class="card" class:active={isActive} on:click={() => dispatch('select', profile.id)} role="button" tabindex="0">
  <div class="info">
    <h4>{profile.name || 'Unnamed Profile'}</h4>
    <p class="detail">{profile.host}:{profile.port}</p>
    <p class="detail">{profile.mode || 'fast3'} / {profile.conn || 2} conn</p>
  </div>
  <div class="actions">
    <button title="Edit" on:click|stopPropagation={() => dispatch('edit', profile.id)}>
      Edit
    </button>
    <button title="Share" on:click|stopPropagation={() => dispatch('share', profile.id)}>
      Share
    </button>
    <button class="danger" title="Delete" on:click|stopPropagation={() => dispatch('delete', profile.id)}>
      Del
    </button>
  </div>
</div>

<style>
  .card {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius);
    cursor: pointer;
    transition: border-color 0.15s, background 0.15s;
  }

  .card:hover {
    background: var(--bg-hover);
  }

  .card.active {
    border-color: var(--accent-color);
    background: var(--accent-muted);
  }

  h4 {
    margin: 0 0 0.25rem;
    color: var(--text-primary);
    font-size: 0.95rem;
  }

  .detail {
    margin: 0;
    color: var(--text-secondary);
    font-size: 0.8rem;
    font-family: var(--font-mono);
  }

  .actions {
    display: flex;
    gap: 0.5rem;
  }

  .actions button {
    background: var(--bg-input);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    padding: 0.35rem 0.6rem;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.75rem;
    transition: background 0.15s, color 0.15s;
  }

  .actions button:hover {
    background: var(--bg-hover);
    color: var(--text-primary);
  }

  .actions button.danger:hover {
    color: var(--color-error);
    border-color: var(--color-error);
  }
</style>
