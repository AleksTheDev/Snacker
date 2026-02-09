<script lang="ts">
    import { supabase } from "$lib/supabaseClient";
    import { session } from "$lib/session";

    let isOpen = false;
    let isLoading = false;
    let title = "";
    let description = "";
    let selectedFiles: File[] = [];
    let fileInputElement: HTMLInputElement;

    interface FileWithIndex {
        file: File;
        index: number;
    }

    function openModal() {
        isOpen = true;
        title = "";
        description = "";
        selectedFiles = [];
    }

    function closeModal() {
        isOpen = false;
    }

    function handleFileSelect(event: Event) {
        const input = event.target as HTMLInputElement;
        if (input.files) {
            // Add new files to the array, maintaining order
            selectedFiles = [...selectedFiles, ...Array.from(input.files)];
            // Reset the input
            input.value = "";
        }
    }

    function removeFile(index: number) {
        selectedFiles = selectedFiles.filter((_, i) => i !== index);
    }

    async function uploadImages(offerId: bigint, userId: string): Promise<void> {
        const filesWithIndex: FileWithIndex[] = selectedFiles.map((file, idx) => ({
            file,
            index: idx + 1,
        }));

        for (const { file, index } of filesWithIndex) {
            try {
                // Upload image to storage
                const storagePath = `${userId}/offer${offerId}/${crypto.randomUUID()}.jpg`;
                const { error: uploadError } = await supabase.storage.from("images").upload(storagePath, file);

                if (uploadError) {
                    throw uploadError;
                }

                // Get public URL
                const { data: publicUrlData } = supabase.storage.from("images").getPublicUrl(storagePath);

                const publicUrl = publicUrlData.publicUrl;

                // Insert image record into database
                const { error: insertError } = await supabase.from("image").insert({
                    offer_id: offerId,
                    index: index,
                    url: publicUrl,
                    user_id: userId,
                });

                if (insertError) {
                    throw insertError;
                }
            } catch (error) {
                console.error(`Error uploading image ${index}:`, error);
                throw error;
            }
        }
    }

    async function handleSubmit() {
        if (!title.trim() || !description.trim()) {
            alert("Моля попълнете всички полета");
            return;
        }

        const user = $session?.user;
        if (!user) {
            alert("Трябва да сте логнати");
            return;
        }

        isLoading = true;

        try {
            // Create offer
            const { data: offerData, error: offerError } = await supabase
                .from("offer")
                .insert({
                    title: title.trim(),
                    description: description.trim(),
                    user_id: user.id,
                })
                .select()
                .single();

            if (offerError) {
                throw offerError;
            }

            // Upload images if any
            if (selectedFiles.length > 0) {
                await uploadImages(offerData.id, user.id);
            }

            // Close modal and reset form
            closeModal();
            alert("Оферта е създадена успешно!");
        } catch (error) {
            console.error("Error creating offer:", error);
            alert("Грешка при създаване на оферта. Моля опитайте отново.");
        } finally {
            isLoading = false;
        }
    }
</script>

<!-- Plus Button -->
<button class="btn btn-dark rounded-circle p-0" style="width: 3rem; height: 3rem; font-size: 2rem;" onclick={openModal}>
    <i class="bi bi-plus"></i>
</button>

<!-- Modal -->
{#if isOpen}
    <div class="modal-overlay" onclick={closeModal}>
        <div class="modal-content" onclick={(e) => e.stopPropagation()}>
            <div class="modal-header">
                <h5 class="modal-title">Добавяне на оферта</h5>
                <button type="button" class="btn-close" onclick={closeModal} disabled={isLoading}></button>
            </div>

            <div class="modal-body">
                <!-- Title Input -->
                <div class="mb-3">
                    <label for="title" class="form-label">Название</label>
                    <input type="text" class="form-control" id="title" bind:value={title} placeholder="Въведете название" disabled={isLoading} />
                </div>

                <!-- Description Input -->
                <div class="mb-3">
                    <label for="description" class="form-label">Описание</label>
                    <textarea class="form-control" id="description" bind:value={description} rows="4" placeholder="Въведете описание" disabled={isLoading}
                    ></textarea>
                </div>

                <!-- Image Upload -->
                <div class="mb-3">
                    <label for="images" class="form-label">Изображения</label>
                    <input
                        type="file"
                        class="form-control"
                        id="images"
                        multiple
                        accept="image/jpeg"
                        bind:this={fileInputElement}
                        onchange={handleFileSelect}
                        disabled={isLoading}
                    />
                    <small class="text-muted">Изберете няколко изображения (не е задължително)</small>
                </div>

                <!-- Image Preview -->
                {#if selectedFiles.length > 0}
                    <div class="mb-3">
                        <label class="form-label">Избрани изображения ({selectedFiles.length})</label>
                        <div class="image-preview-container">
                            {#each selectedFiles as file, idx (idx)}
                                <div class="image-preview-item">
                                    <div class="image-preview-index">{idx + 1}</div>
                                    <img src={URL.createObjectURL(file)} alt="Preview {idx + 1}" class="image-preview" />
                                    <button type="button" class="btn btn-sm btn-danger" onclick={() => removeFile(idx)} disabled={isLoading}> Премахни </button>
                                    <small class="text-muted d-block">{file.name}</small>
                                </div>
                            {/each}
                        </div>
                    </div>
                {/if}
            </div>

            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" onclick={closeModal} disabled={isLoading}> Отмяна </button>
                <button type="button" class="btn btn-primary" onclick={handleSubmit} disabled={isLoading}>
                    {#if isLoading}
                        <span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>
                        Зареждане...
                    {:else}
                        Създай оферта
                    {/if}
                </button>
            </div>
        </div>
    </div>
{/if}

<style>
    .modal-overlay {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background-color: rgba(0, 0, 0, 0.5);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 1050;
    }

    .modal-content {
        background-color: white;
        border-radius: 0.5rem;
        box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.15);
        max-width: 500px;
        width: 90%;
        max-height: 90vh;
        overflow-y: auto;
    }

    .modal-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 1rem;
        border-bottom: 1px solid #dee2e6;
    }

    .modal-title {
        margin: 0;
    }

    .btn-close {
        background: transparent;
        border: 0;
        font-size: 1.5rem;
        cursor: pointer;
        opacity: 0.5;
    }

    .btn-close:hover {
        opacity: 0.75;
    }

    .modal-body {
        padding: 1rem;
    }

    .modal-footer {
        display: flex;
        justify-content: flex-end;
        gap: 0.5rem;
        padding: 1rem;
        border-top: 1px solid #dee2e6;
    }

    .image-preview-container {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
        gap: 1rem;
    }

    .image-preview-item {
        position: relative;
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 0.5rem;
    }

    .image-preview {
        width: 120px;
        height: 120px;
        object-fit: cover;
        border-radius: 0.25rem;
        border: 1px solid #dee2e6;
    }

    .image-preview-index {
        position: absolute;
        top: 0.25rem;
        right: 0.25rem;
        background-color: #007bff;
        color: white;
        border-radius: 50%;
        width: 24px;
        height: 24px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-weight: bold;
        font-size: 0.875rem;
    }
</style>
