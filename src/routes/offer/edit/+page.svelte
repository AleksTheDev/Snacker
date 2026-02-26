<script lang="ts">
    import { onMount } from "svelte";
    import { supabase } from "$lib/supabaseClient";
    import { session } from "$lib/session";
    import { page } from "$app/stores";
    import { goto } from "$app/navigation";

    let title = "";
    let description = "";
    let price: string = "";
    let isFree: boolean = false;
    let profile: any = null;
    let selectedFiles: File[] = [];
    let isLoading = false;
    let fileInputElement: HTMLInputElement;
    let offerId: any = null;
    let offer: any = null;

    interface FileWithIndex {
        file: File;
        index: number;
    }

    function handleFileSelect(event: Event) {
        const input = event.target as HTMLInputElement;
        if (input.files) {
            selectedFiles = [...selectedFiles, ...Array.from(input.files)];
            input.value = "";
        }
    }

    function removeFile(index: number) {
        selectedFiles = selectedFiles.filter((_, i) => i !== index);
    }

    async function uploadImages(offerId: any, userId: string) {
        const filesWithIndex: FileWithIndex[] = selectedFiles.map((file, idx) => ({ file, index: idx + 1 }));
        for (const { file, index } of filesWithIndex) {
            const mime = file.type || "image/jpeg";
            const ext = mime.split("/").pop() || "jpg";
            const filename = `${crypto.randomUUID()}.${ext}`;
            const storagePath = `${userId}/offer${offerId}/${filename}`;
            const { error: uploadError } = await supabase.storage
                .from("images")
                .upload(storagePath, file, { cacheControl: "3600", upsert: false, contentType: mime } as any);
            if (uploadError) throw uploadError;

            let publicUrl: string | null = null;
            try {
                const { data } = supabase.storage.from("images").getPublicUrl(storagePath);
                publicUrl = (data as any)?.publicUrl || null;
            } catch (e) {}
            if (!publicUrl) {
                try {
                    const { data: sd, error: se } = await supabase.storage.from("images").createSignedUrl(storagePath, 60 * 60 * 24);
                    if (!se && sd?.signedUrl) publicUrl = sd.signedUrl;
                } catch (e) {}
            }
            if (!publicUrl) throw new Error("Could not obtain URL for uploaded image");
            const { error: insertError } = await supabase.from("image").insert({ offer_id: offerId, index, url: publicUrl });
            if (insertError) throw insertError;
        }
    }

    async function deleteOldImages(offerId: any) {
        try {
            const { data: images, error: imagesError } = await supabase.from("image").select("*").eq("offer_id", offerId);
            if (imagesError) throw imagesError;

            const pathsToRemove: string[] = [];
            for (const img of images || []) {
                const url: string = img.url || "";
                const m = url.match(/\/storage\/v1\/object\/(?:public|sign)\/images\/(.+)$/);
                if (m && m[1]) {
                    try {
                        pathsToRemove.push(decodeURIComponent(m[1]));
                    } catch (e) {
                        pathsToRemove.push(m[1]);
                    }
                }
            }

            if (pathsToRemove.length > 0) {
                const { error: removeError } = await supabase.storage.from("images").remove(pathsToRemove);
                if (removeError) console.warn("Error removing storage files:", removeError);
            }

            const { error: delImgErr } = await supabase.from("image").delete().eq("offer_id", offerId);
            if (delImgErr) console.warn("Error deleting image rows:", delImgErr);
        } catch (e) {
            console.warn("Error deleting old images:", e);
        }
    }

    async function handleSubmit() {
        if (!title.trim() || !description.trim()) {
            alert("Моля попълнете всички полета");
            return;
        }
        let user: any = $session?.user;
        if (!user) {
            try {
                const { data } = await supabase.auth.getSession();
                user = (data as any)?.session?.user || null;
            } catch (e) {
                user = null;
            }
        }
        if (!user) {
            alert("Трябва да сте логнати");
            return;
        }

        isLoading = true;
        try {
            // Ensure we have the user's profile
            let prof = profile;
            if (!prof) {
                const { data: p, error: profileError } = await supabase.from("profile").select("id").eq("user_id", user.id).maybeSingle();
                if (profileError) throw profileError;
                if (!p) {
                    alert("Няма регистриран профил. Моля първо създайте профил.");
                    goto("/register");
                    return;
                }
                prof = p;
            }

            // Update offer
            const updatePayload: any = { title: title.trim(), description: description.trim() };
            // compute price value
            let priceValue = 0;
            if (!isFree) {
                if (!price || isNaN(Number(price)) || Number(price) < 0) {
                    alert("Моля въведете валидна цена (неотрицателно число, две десетични)");
                    isLoading = false;
                    return;
                }
                priceValue = Math.round(Number(price) * 100) / 100;
            }
            updatePayload.price = priceValue;

            const { data: updated, error: updateError } = await supabase.from("offer").update(updatePayload).eq("id", offerId).select().single();
            if (updateError) throw updateError;

            // If new images were selected, delete old and upload new
            if (selectedFiles.length > 0) {
                await deleteOldImages(offerId);
                await uploadImages(offerId, user.id);
            }

            goto(`/offer/${offerId}`);
        } catch (e) {
            console.error("Error updating offer:", e);
            alert("Грешка при обновяване. Моля опитайте отново.");
        } finally {
            isLoading = false;
        }
    }

    onMount(async () => {
        // read id from query params
        offerId = $page.url.searchParams.get("id");
        if (!offerId) {
            alert("Невалидна страница за редакция: липсва оферта.");
            goto("/");
            return;
        }

        // Load current user
        let user: any = $session?.user;
        if (!user) {
            try {
                const { data } = await supabase.auth.getSession();
                user = (data as any)?.session?.user || null;
            } catch (e) {
                user = null;
            }
        }
        if (!user) {
            goto("/login");
            return;
        }

        // Fetch offer and ensure ownership
        try {
            const { data, error } = await supabase
                .from("offer")
                .select("*, image(*), profile(id,user_id,name,location,phone_number)")
                .eq("id", offerId)
                .maybeSingle();
            if (error) throw error;
            if (!data) {
                alert("Оферта не е намерена.");
                goto("/");
                return;
            }
            offer = data;
            if (!offer.profile || offer.profile.user_id !== user.id) {
                alert("Нямате права да редактирате тази обява.");
                goto(`/offer/${offerId}`);
                return;
            }

            // Prefill fields
            title = offer.title || "";
            description = offer.description || "";
            price = offer.price != null ? Number(offer.price).toFixed(2) : "";
            isFree = Number(offer.price) === 0;

            // Load profile row for this user
            try {
                const { data: prof, error: profErr } = await supabase
                    .from("profile")
                    .select("id,name,location,phone_number")
                    .eq("user_id", user.id)
                    .maybeSingle();
                if (profErr) console.error("Profile lookup error:", profErr);
                if (!prof) {
                    goto("/register");
                    return;
                }
                profile = prof;
            } catch (e) {
                console.error(e);
            }
        } catch (e) {
            console.error("Error loading offer for edit:", e);
            alert("Грешка при зареждане. Моля опитайте отново.");
            goto("/");
        }
    });
</script>

<main class="container py-4">
    <h2>Редактирай обява</h2>
    <div class="card p-3 bg-transparent border-0 shadow-none">
        <div class="mb-3">
            <label class="form-label">Название</label>
            <input class="form-control" bind:value={title} placeholder="Въведете название" disabled={isLoading} />
        </div>
        <div class="mb-3">
            <label class="form-label">Описание</label>
            <textarea class="form-control" rows={4} bind:value={description} disabled={isLoading}></textarea>
        </div>
        <div class="mb-3">
            <label class="form-label">Профил</label>
            <input class="form-control" value={profile?.name ?? ""} disabled />
        </div>
        <div class="mb-3 form-check">
            <input
                class="form-check-input"
                type="checkbox"
                id="isFreeEdit"
                bind:checked={isFree}
                on:change={() => {
                    if (isFree) price = "";
                }}
                disabled={isLoading}
            />
            <label class="form-check-label" for="isFreeEdit">Безплатно</label>
        </div>
        {#if !isFree}
            <div class="mb-3">
                <label class="form-label">Цена (€)</label>
                <input class="form-control" type="number" min="0" step="0.01" bind:value={price} placeholder="0.00" disabled={isLoading} />
                <small class="text-muted">Въведете цена в евро (напр. 3.50)</small>
            </div>
        {/if}

        <!-- <div class="mb-3">
            <label class="form-label">Текущи изображения</label>
            {#if offer && offer.images && offer.images.length > 0}
                <div class="image-preview-container">
                    {#each offer.images as img, idx}
                        <div class="image-preview-item">
                            <div class="image-preview-index">{idx + 1}</div>
                            <img src={img.url} class="image-preview" />
                            <small class="text-muted">{img.url}</small>
                        </div>
                    {/each}
                </div>
            {:else}
                <div class="text-muted">Няма изображения</div>
            {/if}
        </div> -->

        <div class="mb-3">
            <label class="form-label">Нови изображения (по избор)</label>
            <input type="file" class="form-control" multiple accept="image/*" bind:this={fileInputElement} on:change={handleFileSelect} disabled={isLoading} />
            <small class="text-muted">Ако изберете изображения, старите ще бъдат заменени.</small>
        </div>

        {#if selectedFiles.length > 0}
            <div class="mb-3">
                <div class="image-preview-container">
                    {#each selectedFiles as file, idx}
                        <div class="image-preview-item">
                            <div class="image-preview-index">{idx + 1}</div>
                            <img src={URL.createObjectURL(file)} class="image-preview" />
                            <button class="btn btn-sm btn-danger" on:click={() => removeFile(idx)} disabled={isLoading}>Премахни</button>
                            <small class="text-muted">{file.name}</small>
                        </div>
                    {/each}
                </div>
            </div>
        {/if}

        <div class="d-flex justify-content-end gap-2">
            <button class="btn btn-secondary" on:click={() => goto(`/offer/${offerId}`)} disabled={isLoading}>Отказ</button>
            <button class="btn btn-primary" on:click={handleSubmit} disabled={isLoading}>
                {#if isLoading}<span class="spinner-border spinner-border-sm me-2" role="status"></span>Обновявам...{:else}Обнови обявата{/if}
            </button>
        </div>
    </div>
</main>
