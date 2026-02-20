<script lang="ts">
    import { onMount } from "svelte";
    import { page } from "$app/stores";
    import { supabase } from "$lib/supabaseClient";
    import { goto } from "$app/navigation";

    let offer: any = null;
    let loading = true;

    $: id = $page.params.id;

    async function fetchOffer() {
        loading = true;
        const { data, error } = await supabase.from("offer").select("*, image(*)").eq("id", id).single();

        if (error) {
            console.error("Error loading offer:", error);
            offer = null;
        } else {
            const imgs = data.image ?? data.images ?? [];
            offer = { ...data, images: (imgs || []).sort((a: any, b: any) => (a.index ?? 0) - (b.index ?? 0)) };
        }

        loading = false;
    }

    onMount(() => {
        fetchOffer();
    });

    function goBack() {
        history.length > 1 ? history.back() : goto("/");
    }
</script>

<main class="container py-4">
    {#if loading}
        <div class="d-flex justify-content-center py-5">
            <div class="spinner-border" role="status"><span class="visually-hidden">Loading...</span></div>
        </div>
    {:else if !offer}
        <div class="text-danger">Оферта не е намерена.</div>
    {:else}
        <div>
            <button class="btn shadow-sm mb-3 btn-icon-back" on:click={goBack} aria-label="Назад">
                <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="currentColor" viewBox="0 0 16 16" aria-hidden>
                    <path
                        fill-rule="evenodd"
                        d="M11.354 1.646a.5.5 0 0 1 0 .708L5.707 8l5.647 5.646a.5.5 0 0 1-.708.708l-6-6a.5.5 0 0 1 0-.708l6-6a.5.5 0 0 1 .708 0z"
                    />
                </svg>
            </button>
            <div class="card shadow-sm bg-transparent border-0 shadow-none">
                <div class="row g-0">
                    <div class="col-md-5">
                        {#if offer.images && offer.images.length > 0}
                            <div id={`offerCarousel-${offer.id}`} class="carousel slide" data-bs-ride="carousel">
                                <div class="carousel-inner">
                                    {#each offer.images as img, i}
                                        <div class={`carousel-item${i === 0 ? " active" : ""}`}>
                                            <img src={img.url} class="d-block w-100 offer-carousel-image" alt={`${offer.title} ${i + 1}`} />
                                        </div>
                                    {/each}
                                </div>
                                {#if offer.images.length > 1}
                                    <button class="carousel-control-prev" type="button" data-bs-target={`#offerCarousel-${offer.id}`} data-bs-slide="prev">
                                        <span class="carousel-control-prev-icon" aria-hidden="true"></span>
                                        <span class="visually-hidden">Previous</span>
                                    </button>
                                    <button class="carousel-control-next" type="button" data-bs-target={`#offerCarousel-${offer.id}`} data-bs-slide="next">
                                        <span class="carousel-control-next-icon" aria-hidden="true"></span>
                                        <span class="visually-hidden">Next</span>
                                    </button>
                                {/if}
                            </div>
                        {:else}
                            <div class="bg-light d-flex align-items-center justify-content-center no-image-placeholder">Без изображение</div>
                        {/if}
                    </div>
                    <div class="col-md-7">
                        <div class="card-body offer-card-body">
                            <h1 class="card-title">{offer.title}</h1>
                            <p class="text-muted">{offer.description}</p>
                            {#if offer.price}
                                <p><strong>Цена:</strong> {offer.price}</p>
                            {/if}
                            {#if offer.phone}
                                <p><strong>Телефон:</strong> <a class="text-white" href="tel:{offer.phone}">{offer.phone}</a></p>
                            {/if}
                            {#if offer.location}
                                <p><strong>Местоположение:</strong> {offer.location}</p>
                            {/if}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    {/if}
</main>
