<script lang="ts">
    import { onMount } from "svelte";
    import { session } from "$lib/session";
    import { supabase } from "$lib/supabaseClient";
    import AddOfferModal from "$lib/AddOfferModal.svelte";
    import OfferCard from "$lib/OfferCard.svelte";

    let offers: any[] = [];
    let loading = true;
    let searchQuery = "";

    $: filteredOffers =
        searchQuery.trim() === ""
            ? offers
            : offers.filter((o: any) => {
                  const hay = (
                      (o.title ?? "") +
                      " " +
                      (o.description ?? "") +
                      " " +
                      (o.location ?? "") +
                      " " +
                      (o.phone ?? "") +
                      " " +
                      (o.profile_name ?? "")
                  ).toLowerCase();
                  const q = searchQuery.toLowerCase().trim();
                  return q.split(/\s+/).every((tok) => hay.includes(tok));
              });

    async function fetchOffers() {
        loading = true;
        // Include related profile and images; derive offer.location and offer.phone from profile
        const { data, error } = await supabase
            .from("offer")
            .select("*, image(*), profile(name,location,phone_number)")
            .order("created_at", { ascending: false });

        if (error) {
            console.error("Error loading offers:", error);
            offers = [];
        } else if (data) {
            offers = data.map((o: any) => {
                const imgs = o.image ?? o.images ?? [];
                const normalized = { ...o, images: (imgs || []).sort((a: any, b: any) => (a.index ?? 0) - (b.index ?? 0)) };
                // copy profile fields to top-level for UI compatibility
                if (o.profile) {
                    normalized.location = o.profile.location ?? normalized.location;
                    normalized.phone = o.profile.phone_number ?? normalized.phone;
                    normalized.profile_name = o.profile.name ?? null;
                }
                return normalized;
            });
        }

        loading = false;
    }

    onMount(() => {
        fetchOffers();
        const handler = () => fetchOffers();
        window.addEventListener("offer:created", handler);
        return () => window.removeEventListener("offer:created", handler);
    });

    // navigation to individual offer pages is handled by links / routes

    import { goto } from "$app/navigation";

    async function logout() {
        try {
            const { error } = await supabase.auth.signOut();
            if (error) console.error("Logout error:", error);
            // session store will update; navigate to home
            goto("/");
        } catch (e) {
            console.error(e);
        }
    }
</script>

<main class="d-flex flex-column min-vh-100">
    <div class="container py-4">
        <div class="d-flex align-items-center justify-content-between mb-3">
            <h2 class="mb-0">Налични оферти</h2>
            {#if $session}
                <button class="btn btn-sm btn-danger" on:click={logout} aria-label="Изход">
                    <i class="bi bi-box-arrow-in-left"></i>
                </button>
            {/if}
        </div>

        <div class="mb-3 d-flex">
            <input class="form-control me-2" type="search" placeholder="Търсене по заглавие, описание или локация" bind:value={searchQuery} />
        </div>

        {#if loading}
            <div class="d-flex justify-content-center py-5">
                <div class="spinner-border" role="status"><span class="visually-hidden">Loading...</span></div>
            </div>
        {:else if offers.length === 0}
            <div class="text-muted">Няма налични оферти в момента.</div>
        {:else if filteredOffers.length === 0}
            <div class="text-muted">Няма оферти, съвпадащи с търсенето.</div>
        {:else}
            <div class="row row-cols-1 row-cols-sm-2 row-cols-md-3 g-3">
                {#each filteredOffers as offer, i (offer.id ?? i)}
                    <div class="col">
                        <OfferCard {offer} />
                    </div>
                {/each}
            </div>
        {/if}
    </div>

    <footer class="border-top py-4">
        <div class="text-center">
            <!-- footer left intentionally empty; AddOffer button is fixed to viewport -->
        </div>
    </footer>

    <div class="add-offer-fixed">
        <AddOfferModal />
    </div>
</main>
