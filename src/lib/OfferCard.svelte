<script lang="ts">
    export let offer: any;
    const thumb = offer?.images && offer.images.length > 0 ? offer.images[0].url : null;
</script>

<a href={`/offer/${offer.id}`} class="card h-100 text-decoration-none text-body">
    {#if thumb}
        <img src={thumb} class="card-img-top" alt={offer.title} style="height:200px; object-fit:cover;" />
    {:else}
        <div class="bg-light d-flex align-items-center justify-content-center" style="height:200px;">Без изображение</div>
    {/if}
    <div class="card-body">
        <h5 class="card-title">{offer.title}</h5>
    </div>
</a>

<style>
a.card { display:block }
</style>
