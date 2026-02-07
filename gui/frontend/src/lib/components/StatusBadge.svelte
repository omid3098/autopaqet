<script lang="ts">
  import type { ConnectionState } from '../stores/connection';

  export let state: ConnectionState = 'idle';

  const stateColors: Record<ConnectionState, string> = {
    idle: 'var(--color-idle)',
    testing: 'var(--color-starting)',
    connected: 'var(--color-connected)',
    error: 'var(--color-error)',
  };
</script>

<span class="badge" style="background: {stateColors[state]}" />

<style>
  .badge {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }
</style>
