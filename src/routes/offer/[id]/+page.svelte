<script lang="ts">
    import { onMount } from "svelte";
    import { page } from "$app/stores";
    import { supabase } from "$lib/supabaseClient";
    import { session } from "$lib/session";
    import { goto } from "$app/navigation";

    let offer: any = null;
    let loading = true;
    let showDeleteModal = false;
    let isDeleting = false;
    let isOwner = false;

    $: id = $page.params.id;

    async function fetchOffer() {
        loading = true;
        const { data, error } = await supabase.from("offer").select("*, image(*), profile(id,user_id,name,location,phone_number)").eq("id", id).single();

        if (error) {
            console.error("Error loading offer:", error);
            offer = null;
        } else {
            const imgs = data.image ?? data.images ?? [];
            const normalized = { ...data, images: (imgs || []).sort((a: any, b: any) => (a.index ?? 0) - (b.index ?? 0)) };
            if (data.profile) {
                normalized.location = data.profile.location ?? normalized.location;
                normalized.phone = data.profile.phone_number ?? normalized.phone;
                normalized.profile_name = data.profile.name ?? null;
            }
            offer = normalized;
            // determine ownership if session present
            const s = $session;
            isOwner = !!(s?.user && offer?.profile && offer.profile.user_id === s.user.id);
        }

        loading = false;
    }

    onMount(() => {
        fetchOffer();
    });

    $: if ($session && offer) {
        isOwner = !!($session.user && offer?.profile && offer.profile.user_id === $session.user.id);
    }

    function goBack() {
        goto("/");
    }

    async function deleteOffer() {
        if (!offer) return;
        const user = $session?.user;
        if (!user) {
            alert("Трябва да сте логнати за да изтриете обявата.");
            return;
        }
        if (!offer.profile || offer.profile.user_id !== user.id) {
            alert("Нямате права да изтриете тази обява.");
            return;
        }

        isDeleting = true;
        try {
            // Fetch image records
            const { data: images, error: imagesError } = await supabase.from("image").select("*").eq("offer_id", offer.id);
            if (imagesError) throw imagesError;

            const pathsToRemove: string[] = [];
            for (const img of images || []) {
                const url: string = img.url || "";
                // Try to extract the storage path from common Supabase public URL patterns
                // e.g. https://<project>.supabase.co/storage/v1/object/public/images/<path>
                const m = url.match(/\/storage\/v1\/object\/(?:public|sign)\/images\/(.+)$/);
                if (m && m[1]) {
                    // decode in case of encoded components
                    try {
                        pathsToRemove.push(decodeURIComponent(m[1]));
                    } catch (e) {
                        pathsToRemove.push(m[1]);
                    }
                }
            }

            if (pathsToRemove.length > 0) {
                try {
                    const { error: removeError } = await supabase.storage.from("images").remove(pathsToRemove);
                    if (removeError) console.warn("Error removing storage files:", removeError);
                } catch (e) {
                    console.warn("Storage removal failed:", e);
                }
            }

            // Delete image rows
            const { error: delImgErr } = await supabase.from("image").delete().eq("offer_id", offer.id);
            if (delImgErr) console.warn("Error deleting image rows:", delImgErr);

            // Delete offer
            const { error: delOfferErr } = await supabase.from("offer").delete().eq("id", offer.id);
            if (delOfferErr) throw delOfferErr;

            // Success
            goto("/");
        } catch (e) {
            console.error("Error deleting offer:", e);
            alert("Грешка при изтриване. Моля опитайте отново.");
        } finally {
            isDeleting = false;
            showDeleteModal = false;
        }
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
                            {#if offer.price != null}
                                <p><strong>Цена:</strong> {Number(offer.price) === 0 ? "Безплатно" : `${Number(offer.price).toFixed(2)} €`}</p>
                            {/if}
                            {#if offer.phone}
                                <p><strong>Телефон:</strong> <a class="text-white" href="tel:{offer.phone}">{offer.phone}</a></p>
                            {/if}
                            {#if offer.location}
                                <p><strong>Местоположение:</strong> {offer.location}</p>
                            {/if}
                            {#if offer.created_at}
                                <p class="text-muted"><small>От: {offer.profile_name}<br />Създадена: {new Date(offer.created_at).toLocaleString()}</small></p>
                            {/if}
                            {#if isOwner}
                                <div class="d-flex gap-2 mb-3">
                                    <button class="btn btn-outline-light" on:click={() => goto(`/offer/edit?id=${offer.id}`)}>Редактирай</button>
                                    <button class="btn btn-danger" on:click={() => (showDeleteModal = true)}>Изтрий</button>
                                </div>
                            {/if}
                        </div>
                    </div>
                </div>
            </div>
        </div>
        {#if showDeleteModal}
            <div class="modal-backdrop" style="position:fixed;inset:0;display:flex;align-items:center;justify-content:center;z-index:60;">
                <div class="card p-3" style="max-width:420px;width:100%;">
                    <h3>Потвърдете изтриване</h3>
                    <p class="text-muted">Сигурни ли сте, че искате да изтриете тази обява? Това действие не може да бъде върнато.</p>
                    <div class="d-flex gap-2">
                        <button class="btn btn-danger" on:click={deleteOffer} disabled={isDeleting}>
                            {#if isDeleting}<span class="spinner-border spinner-border-sm me-2"></span>Изтривам...{:else}Изтрий{/if}
                        </button>
                        <button class="btn btn-secondary" on:click={() => (showDeleteModal = false)} disabled={isDeleting}>Отказ</button>
                    </div>
                </div>
            </div>
        {/if}
    {/if}
</main>
