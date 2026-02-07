<script lang="ts">
  import type { DiagStep } from '../stores/diag';

  export let steps: DiagStep[] = [];
</script>

<div class="diag-progress">
  {#each steps as step (step.id)}
    <div class="diag-step" class:running={step.status === 'running'} class:pass={step.status === 'pass'} class:fail={step.status === 'fail'} class:warn={step.status === 'warn'} class:skip={step.status === 'skip'}>
      <span class="icon">
        {#if step.status === 'running'}
          <span class="spinner" />
        {:else if step.status === 'pass'}
          <span class="check">&#10003;</span>
        {:else if step.status === 'fail'}
          <span class="cross">&#10007;</span>
        {:else if step.status === 'warn'}
          <span class="warning">&#9888;</span>
        {:else}
          <span class="dash">&mdash;</span>
        {/if}
      </span>
      <div class="content">
        <span class="message">{step.message}</span>
        {#if step.detail}
          <span class="detail">{step.detail}</span>
        {/if}
      </div>
    </div>
  {/each}
</div>

<style>
  .diag-progress {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    margin: 1rem 0;
  }

  .diag-step {
    display: flex;
    align-items: flex-start;
    gap: 0.5rem;
    font-size: 0.85rem;
    line-height: 1.4;
  }

  .icon {
    flex-shrink: 0;
    width: 18px;
    text-align: center;
    font-size: 0.9rem;
  }

  .content {
    display: flex;
    flex-direction: column;
    gap: 0.1rem;
    min-width: 0;
  }

  .message {
    color: var(--text-primary);
  }

  .detail {
    color: var(--text-secondary);
    font-size: 0.75rem;
    white-space: pre-wrap;
    word-break: break-word;
  }

  .pass .icon { color: var(--color-connected); }
  .fail .icon { color: var(--color-error); }
  .warn .icon { color: var(--color-starting); }
  .skip .icon { color: var(--color-idle); }
  .running .icon { color: var(--color-starting); }

  .fail .message { color: var(--color-error); }
  .warn .message { color: var(--color-starting); }
  .skip .message { color: var(--text-secondary); }

  .spinner {
    display: inline-block;
    width: 10px;
    height: 10px;
    border: 2px solid var(--color-starting);
    border-top-color: transparent;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }
</style>
