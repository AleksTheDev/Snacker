<script lang="ts">
    export let offer: any;
    const thumb = offer?.images && offer.images.length > 0 ? offer.images[0].url : null;
</script>

<a href={`/offer/${offer.id}`} class="card h-100 text-decoration-none text-body offer-card">
    {#if thumb}
        <img src={thumb} class="card-img-top offer-image" alt={offer.title} />
    {:else}
        <div class="bg-light d-flex align-items-center justify-content-center no-image-placeholder-200">Без изображение</div>
    {/if}
    <div class="card-body">
        <h5 class="card-title">{offer.title}</h5>
        {#if offer.location}
            <small class="text-muted d-block mb-2">📍 {offer.location}</small>
        {/if}
        {#if offer.phone}
            <small class="text-muted d-block">📞 {offer.phone}</small>
        {/if}
    </div>
</a>
