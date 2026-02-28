<script lang="ts">
    export let offer: any;
    const thumb = offer?.images && offer.images.length > 0 ? offer.images[0].url : null;
    const rawPrice = offer?.price;
    const priceDisplay = rawPrice == null ? null : Number(rawPrice) === 0 ? "Безплатно" : `${Number(rawPrice).toFixed(2)} €`;
</script>

<a href={`/offer/${offer.id}`} class="card h-100 text-decoration-none text-body offer-card">
    {#if thumb}
        <img src={thumb} class="card-img-top offer-image" alt={offer.title} />
    {:else}
        <div class="bg-light d-flex align-items-center justify-content-center no-image-placeholder-200">Без изображение</div>
    {/if}
    <div class="card-body">
        <h1 class="card-title">{offer.title}</h1>
        <hr class="mt-0 mb-3" />
        {#if priceDisplay}
            <h5 class="text-muted d-block mb-1">💶 {priceDisplay}</h5>
        {/if}
        {#if offer.location}
            <h5 class="text-muted d-block mb-2">📍 {offer.location}</h5>
        {/if}
        {#if offer.phone}
            <h5 class="text-muted d-block">📞 {offer.phone}</h5>
        {/if}
    </div>
</a>
