<script lang="ts">
    export let offer: any;
    const thumb = offer?.images && offer.images.length > 0 ? offer.images[0].url : null;
</script>

<a href={`/offer/${offer.id}`} class="card h-100 text-decoration-none text-body offer-card">
    {#if thumb}
        <img src={thumb} class="card-img-top offer-image" alt={offer.title} style="height:200px; object-fit:cover;" />
    {:else}
        <div class="bg-light d-flex align-items-center justify-content-center" style="height:200px;">Без изображение</div>
    {/if}
    <div class="card-body">
        <h5 class="card-title">{offer.title}</h5>
    </div>
</a>

<style>
a.card { display:block }
.offer-card { transition: transform 0.3s ease, box-shadow 0.3s ease; }
.offer-card:hover { transform: translateY(-4px); box-shadow: 0 8px 16px rgba(0, 0, 0, 0.1); }
.offer-image { border-radius: 8px 8px 0 0; }
</style>
