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
                      (o.phone_location ?? "") +
                      " " +
                      (o.address ?? "")
                  ).toLowerCase();
                  const q = searchQuery.toLowerCase().trim();
                  return q.split(/\s+/).every((tok) => hay.includes(tok));
              });

    async function fetchOffers() {
        loading = true;
        const { data, error } = await supabase.from("offer").select("*, image(*)").order("created_at", { ascending: false });

        if (error) {
            console.error("Error loading offers:", error);
            offers = [];
        } else if (data) {
            offers = data.map((o: any) => {
                const imgs = o.image ?? o.images ?? [];
                return { ...o, images: (imgs || []).sort((a: any, b: any) => (a.index ?? 0) - (b.index ?? 0)) };
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

    async function signInWithGoogle() {
        const { data, error } = await supabase.auth.signInWithOAuth({
            provider: "google",
            options: {
                redirectTo: `${window.location.origin}`,
            },
        });
        if (error) {
            console.error("Error signing in:", error);
        }
    }
</script>

{#if !$session}
    <main class="d-flex align-items-center justify-content-center min-vh-100">
        <div class="text-center">
            <h1 class="display-3 fw-bold mb-4">Снакър</h1>
            <button class="btn btn-dark btn-lg" onclick={signInWithGoogle}> Влез с Google </button>
        </div>
    </main>
{:else}
    <main class="d-flex flex-column min-vh-100">
        <div class="container py-4">
            <h2 class="mb-4">Налични оферти</h2>

            <div class="mb-3 d-flex">
                <input class="form-control me-2" type="search" placeholder="Търсене по заглавие, описание или локация" bind:value={searchQuery} />
                <button class="btn btn-secondary" onclick={() => (searchQuery = "")}>Изчисти</button>
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
    </main>

    <div class="add-offer-fixed">
        <AddOfferModal />
    </div>
{/if}
