<script lang="ts">
    import { onMount } from "svelte";
    import { session } from "$lib/session";
    import { supabase } from "$lib/supabaseClient";
    import AddOfferModal from "$lib/AddOfferModal.svelte";
    import OfferCard from "$lib/OfferCard.svelte";

    let offers: any[] = [];
    let loading = true;
    let searchQuery = "";
    let userProfile: any = null;
    let showUserOffersOnly = false;
    let userHasOffers = false;

    $: filteredOffers = ((): any[] => {
        let result = offers;

        // Filter by search query
        if (searchQuery.trim() !== "") {
            result = result.filter((o: any) => {
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
        }

        // Filter by user offers if enabled
        if (showUserOffersOnly && userProfile) {
            result = result.filter((o: any) => o.profile_id === userProfile.id);
        }

        return result;
    })();

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

    async function fetchUserProfile() {
        if (!$session) {
            userProfile = null;
            userHasOffers = false;
            return;
        }

        // Fetch user's profile
        const { data: profileData, error: profileError } = await supabase.from("profile").select("*").eq("user_id", $session.user.id).single();

        if (profileError) {
            console.error("Error loading profile:", profileError);
            userProfile = null;
        } else {
            userProfile = profileData;
            // Check if user has any offers
            const { data: offersData, error: offersError } = await supabase.from("offer").select("id", { count: "exact" }).eq("profile_id", profileData.id);

            if (!offersError && offersData) {
                userHasOffers = offersData.length > 0;
                showUserOffersOnly = userHasOffers; // Default to checked if user has offers
            }
        }
    }

    onMount(() => {
        fetchOffers();
        fetchUserProfile();

        const handler = () => fetchOffers();
        window.addEventListener("offer:created", handler);

        return () => window.removeEventListener("offer:created", handler);
    });

    // Watch for session changes to update profile
    $: if ($session) {
        fetchUserProfile();
    }

    // navigation to individual offer pages is handled by links / routes

    import { goto } from "$app/navigation";

    async function logout() {
        try {
            const { error } = await supabase.auth.signOut();
            if (error) console.error("Logout error:", error);
            // session store will update; navigate to home
            showUserOffersOnly = false;
            userProfile = null;
            goto("/");
        } catch (e) {
            console.error(e);
        }
    }
</script>

<main class="d-flex flex-column min-vh-100">
    <div class="container py-4">
        <div class="d-flex align-items-center justify-content-between mb-3">
            <h1 class="mb-0">Налични оферти</h1>
            <!-- Account Button -->
            {#if $session}
                <div class="dropdown">
                    <button
                        class="btn btn-success btn-sm"
                        type="button"
                        id="accountDropdown"
                        data-bs-toggle="dropdown"
                        aria-expanded="false"
                        aria-label="Профил"
                    >
                        <i class="bi bi-person-circle"></i>
                    </button>
                    <ul class="dropdown-menu dropdown-menu-end" aria-labelledby="accountDropdown">
                        <li>
                            {#if userProfile}
                                <a class="dropdown-item" href="/profile/edit" on:click={() => goto("/profile/edit")}>
                                    <i class="bi bi-pencil-square me-2"></i>Редактирай профил</a
                                >
                            {:else}
                                <a class="dropdown-item" href="/register" on:click={() => goto("/register")}>
                                    <i class="bi bi-pencil-square me-2"></i>Създай профил</a
                                >
                            {/if}
                        </li>
                        <li><hr class="dropdown-divider" /></li>
                        <li><a class="dropdown-item" href="#" on:click|preventDefault={logout}><i class="bi bi-box-arrow-right me-2"></i> Изход</a></li>
                    </ul>
                </div>
            {:else}
                <button class="btn btn-success btn-sm" on:click={() => goto("/login")} aria-label="Вход">
                    <i class="bi bi-person-circle"></i>
                </button>
            {/if}
        </div>

        <div class="mb-3 d-flex flex-column">
            <input class="form-control mb-2" type="search" placeholder="Търсене по заглавие, описание или локация" bind:value={searchQuery} />
            {#if $session && userProfile}
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="showUserOffersOnly" bind:checked={showUserOffersOnly} />
                    <label class="form-check-label" for="showUserOffersOnly"><h5>Покажи само моите оферти</h5> </label>
                </div>
            {/if}
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

    <div class="add-offer-fixed">
        <AddOfferModal />
    </div>
</main>
