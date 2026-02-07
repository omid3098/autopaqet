<script lang="ts">
  import Sidebar from './lib/components/Sidebar.svelte';
  import Connect from './pages/Connect.svelte';
  import Profiles from './pages/Profiles.svelte';
  import Settings from './pages/Settings.svelte';
  import Logs from './pages/Logs.svelte';

  let currentPage = 'connect';
</script>

<main>
  <div class="app-container">
    <Sidebar bind:currentPage />
    <section class="content">
      {#if currentPage === 'connect'}
        <Connect />
      {:else if currentPage === 'profiles'}
        <Profiles />
      {:else if currentPage === 'settings'}
        <Settings />
      {:else if currentPage === 'logs'}
        <Logs />
      {/if}
    </section>
  </div>
</main>

<style>
  .app-container {
    display: flex;
    height: 100vh;
  }

  .content {
    flex: 1;
    padding: 2rem;
    overflow-y: auto;
  }
</style>
