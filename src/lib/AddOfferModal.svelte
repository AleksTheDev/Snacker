<script lang="ts">
    import { goto } from "$app/navigation";
</script>

<!-- Floating add button that navigates to /offer/new -->
<button class="btn btn-primary rounded-circle p-0 add-offer-btn" style="width: 3rem; height: 3rem; font-size: 1.25rem;" on:click={() => goto('/offer/new')} aria-label="Добави обява">
    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" viewBox="0 0 16 16" aria-hidden>
        <path d="M8 4a.5.5 0 0 1 .5.5V7.5H11.5a.5.5 0 0 1 0 1H8.5V11.5a.5.5 0 0 1-1 0V8.5H4.5a.5.5 0 0 1 0-1H7.5V4.5A.5.5 0 0 1 8 4z"/>
    </svg>
</button>

<style>
    .add-offer-btn { box-shadow: 0 0.5rem 1rem rgba(0,0,0,0.15); }
</style>
