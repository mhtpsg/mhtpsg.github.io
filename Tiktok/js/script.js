class VideoPlayer {
    constructor() {
        this.dbName = 'VideoPlayerDB';
        this.dbVersion = 1;
        this.db = null;
        this.videos = [];
        this.currentVideo = null;
        this.init();
    }

    async init() {
        try {
            await this.initDB();
            await this.loadVideos();
            this.setupEventListeners();
            this.renderVideos();
        } catch (error) {
            console.error('Initialization error:', error);
            this.showToast('Gagal inisialisasi database', 'error');
        }
    }

    initDB() {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open(this.dbName, this.dbVersion);

            request.onerror = () => reject(request.error);
            
            request.onsuccess = () => {
                this.db = request.result;
                resolve();
            };

            request.onupgradeneeded = (event) => {
                const db = event.target.result;
                
                // Create videos store
                if (!db.objectStoreNames.contains('videos')) {
                    const videoStore = db.createObjectStore('videos', { keyPath: 'id' });
                    videoStore.createIndex('title', 'title', { unique: false });
                    videoStore.createIndex('uploadDate', 'uploadDate', { unique: false });
                }

                // Create video files store
                if (!db.objectStoreNames.contains('videoFiles')) {
                    db.createObjectStore('videoFiles', { keyPath: 'id' });
                }
            };
        });
    }

    async loadVideos() {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['videos'], 'readonly');
            const store = transaction.objectStore('videos');
            const request = store.getAll();

            request.onsuccess = () => {
                this.videos = request.result.sort((a, b) => 
                    new Date(b.uploadDate) - new Date(a.uploadDate)
                );
                resolve();
            };

            request.onerror = () => reject(request.error);
        });
    }

    setupEventListeners() {
        // Upload form
        document.getElementById('uploadForm').addEventListener('submit', (e) => {
            e.preventDefault();
            this.handleUpload();
        });

        // File input change
        document.getElementById('videoFile').addEventListener('change', this.handleFileSelect.bind(this));

        // Search functionality
        document.getElementById('searchInput').addEventListener('input', this.handleSearch.bind(this));
        
        // Sort functionality
        document.getElementById('sortFilter').addEventListener('change', this.handleSort.bind(this));

        // Click outside modal to close
        document.getElementById('uploadModal').addEventListener('click', (e) => {
            if (e.target === e.currentTarget) {
                this.closeUploadModal();
            }
        });

        document.getElementById('playerModal').addEventListener('click', (e) => {
            if (e.target === e.currentTarget) {
                this.closePlayerModal();
            }
        });

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closeUploadModal();
                this.closePlayerModal();
            }
        });
    }

    handleFileSelect(event) {
        const file = event.target.files[0];
        const fileInfo = document.getElementById('fileInfo');
        
        if (file) {
            // Check file type
            if (!file.type.startsWith('video/')) {
                this.showToast('Mohon pilih file video!', 'error');
                event.target.value = '';
                fileInfo.style.display = 'none';
                return;
            }

            const size = this.formatFileSize(file.size);
            const type = file.type;
            fileInfo.innerHTML = `
                <div style="display: flex; align-items: center; gap: 10px;">
                    <i class="fas fa-video" style="color: var(--primary-color);"></i>
                    <div>
                        <strong>${file.name}</strong><br>
                        <small>Ukuran: ${size} | Tipe: ${type}</small>
                    </div>
                </div>
            `;
            fileInfo.style.display = 'block';

            // Show file size info
            if (file.size > 100 * 1024 * 1024) { // > 100MB
                this.showToast(`File besar terdeteksi (${size}). Upload mungkin memakan waktu lama.`, 'info');
            }
        } else {
            fileInfo.style.display = 'none';
        }
    }

    async handleUpload() {
        const fileInput = document.getElementById('videoFile');
        const titleInput = document.getElementById('videoTitle');
        const descriptionInput = document.getElementById('videoDescription');
        const progressContainer = document.getElementById('uploadProgress');
        const progressFill = document.getElementById('progressFill');
        const progressText = document.getElementById('progressText');
        const submitBtn = document.querySelector('#uploadForm button[type="submit"]');

        const file = fileInput.files[0];
        const title = titleInput.value.trim();
        const description = descriptionInput.value.trim();

        if (!file) {
            this.showToast('Mohon pilih file video!', 'error');
            return;
        }

        if (!title) {
            this.showToast('Mohon masukkan judul video!', 'error');
            return;
        }

        // Disable submit button
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Mengupload...';

        // Show progress
        progressContainer.style.display = 'block';
        progressFill.style.width = '0%';
        progressText.textContent = '0%';

        try {
            const videoId = Date.now().toString();

            this.updateProgress(10, 'Memproses file...');
            await this.delay(200);

            // Get video metadata
            const videoData = await this.getVideoMetadata(file);
            
            this.updateProgress(30, 'Membuat thumbnail...');
            const thumbnail = await this.generateThumbnail(file);

            this.updateProgress(50, 'Menyimpan file video...');
            
            // Store video file in IndexedDB
            await this.storeVideoFile(videoId, file);

            this.updateProgress(80, 'Menyimpan metadata...');

            // Create video metadata object
            const video = {
                id: videoId,
                title: title,
                description: description,
                fileName: file.name,
                fileSize: file.size,
                fileType: file.type,
                thumbnail: thumbnail,
                duration: videoData.duration,
                width: videoData.width,
                height: videoData.height,
                uploadDate: new Date().toISOString(),
                views: 0
            };

            // Store video metadata
            await this.storeVideoMetadata(video);

            this.updateProgress(95, 'Finalisasi...');
            
            // Add to local array
            this.videos.unshift(video);

            this.updateProgress(100, 'Selesai!');
            await this.delay(300);

            this.renderVideos();
            this.showToast(`Video "${title}" berhasil diupload! (${this.formatFileSize(file.size)})`, 'success');
            this.closeUploadModal();

        } catch (error) {
            console.error('Upload error:', error);
            let errorMessage = 'Gagal upload video: ';
            
            if (error.name === 'QuotaExceededError') {
                errorMessage = 'Storage penuh! Hapus beberapa video lama atau gunakan perangkat dengan storage lebih besar.';
            } else if (error.message.includes('network')) {
                errorMessage = 'Koneksi bermasalah. Coba lagi.';
            } else {
                errorMessage += error.message || 'Terjadi kesalahan tidak diketahui.';
            }
            
            this.showToast(errorMessage, 'error');
        } finally {
            // Reset UI
            submitBtn.disabled = false;
            submitBtn.innerHTML = '<i class="fas fa-upload"></i> Upload Video';
            progressContainer.style.display = 'none';
        }
    }

    getVideoMetadata(file) {
        return new Promise((resolve, reject) => {
            const video = document.createElement('video');
            video.preload = 'metadata';

            video.onloadedmetadata = () => {
                resolve({
                    duration: video.duration,
                    width: video.videoWidth,
                    height: video.videoHeight
                });
                URL.revokeObjectURL(video.src);
            };

            video.onerror = () => {
                reject(new Error('Gagal membaca metadata video'));
                URL.revokeObjectURL(video.src);
            };

            video.src = URL.createObjectURL(file);
        });
    }

    generateThumbnail(file) {
        return new Promise((resolve, reject) => {
            const video = document.createElement('video');
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');

            video.onloadedmetadata = () => {
                canvas.width = 320;
                canvas.height = 180;
                video.currentTime = Math.min(2, video.duration * 0.1); // 10% ke dalam video atau 2 detik
            };

            video.onseeked = () => {
                try {
                    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
                    const thumbnail = canvas.toDataURL('image/jpeg', 0.8);
                    resolve(thumbnail);
                } catch (error) {
                    // Fallback: return empty thumbnail
                    resolve('');
                } finally {
                    URL.revokeObjectURL(video.src);
                }
            };

            video.onerror = () => {
                resolve(''); // Return empty thumbnail on error
                URL.revokeObjectURL(video.src);
            };

            video.src = URL.createObjectURL(file);
        });
    }

    storeVideoFile(id, file) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['videoFiles'], 'readwrite');
            const store = transaction.objectStore('videoFiles');
            
            const fileData = {
                id: id,
                file: file,
                timestamp: Date.now()
            };

            const request = store.add(fileData);

            request.onsuccess = () => resolve();
            request.onerror = () => reject(request.error);
        });
    }

    storeVideoMetadata(video) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['videos'], 'readwrite');
            const store = transaction.objectStore('videos');
            
            const request = store.add(video);

            request.onsuccess = () => resolve();
            request.onerror = () => reject(request.error);
        });
    }

    getVideoFile(id) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['videoFiles'], 'readonly');
            const store = transaction.objectStore('videoFiles');
            const request = store.get(id);

            request.onsuccess = () => {
                if (request.result) {
                    resolve(request.result.file);
                } else {
                    reject(new Error('Video file not found'));
                }
            };

            request.onerror = () => reject(request.error);
        });
    }

    updateProgress(percent, message) {
        const progressFill = document.getElementById('progressFill');
        const progressText = document.getElementById('progressText');
        
        progressFill.style.width = percent + '%';
        progressText.textContent = `${percent}% - ${message}`;
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    renderVideos(videosToShow = this.videos) {
        const videoGrid = document.getElementById('videoGrid');
        const noResults = document.getElementById('noResults');

        if (videosToShow.length === 0) {
            videoGrid.innerHTML = `
                <div style="grid-column: 1 / -1; text-align: center; padding: 2rem;">
                    <i class="fas fa-video" style="font-size: 3rem; color: var(--text-light); margin-bottom: 1rem;"></i>
                    <h3>Belum ada video</h3>
                    <p>Klik tombol "Upload Video" untuk menambah video pertama</p>
                    <p style="font-size: 0.9rem; color: var(--text-light); margin-top: 0.5rem;">
                        Mendukung video dengan ukuran berapa pun!
                    </p>
                </div>
            `;
            noResults.style.display = 'none';
            return;
        }

        noResults.style.display = 'none';
        videoGrid.innerHTML = videosToShow.map(video => this.createVideoCard(video)).join('');
    }

    createVideoCard(video) {
        const uploadDate = new Date(video.uploadDate).toLocaleDateString('id-ID');
        const fileSize = this.formatFileSize(video.fileSize);
        const duration = this.formatDuration(video.duration || 0);
        const resolution = video.width && video.height ? `${video.width}x${video.height}` : '';

        return `
            <div class="video-card" onclick="videoPlayer.playVideo('${video.id}')">
                <div class="video-thumbnail">
                    ${video.thumbnail ? 
                        `<img src="${video.thumbnail}" alt="${this.escapeHtml(video.title)}" style="width: 100%; height: 100%; object-fit: cover;">` :
                        `<div style="display: flex; align-items: center; justify-content: center; height: 100%; background: linear-gradient(135deg, var(--primary-color), var(--accent-color)); color: white;">
                            <i class="fas fa-video" style="font-size: 2rem;"></i>
                        </div>`
                    }
                    <div class="play-overlay">
                        <i class="fas fa-play"></i>
                    </div>
                    ${duration ? `<div class="video-duration">${duration}</div>` : ''}
                    ${resolution ? `<div class="video-resolution">${resolution}</div>` : ''}
                </div>
                <div class="video-info">
                    <h3>${this.escapeHtml(video.title)}</h3>
                    <p>${this.escapeHtml(video.description || 'Tidak ada deskripsi')}</p>
                    <div class="video-meta">
                        <span><i class="fas fa-calendar"></i> ${uploadDate}</span>
                        <span><i class="fas fa-hdd"></i> ${fileSize}</span>
                        <span><i class="fas fa-eye"></i> ${video.views || 0}</span>
                    </div>
                    <div class="video-actions">
                        <button onclick="event.stopPropagation(); videoPlayer.deleteVideo('${video.id}')" class="delete-btn">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </div>
            </div>
        `;
    }

    formatDuration(seconds) {
        if (!seconds || seconds === 0) return '';
        
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = Math.floor(seconds % 60);
        
        if (hours > 0) {
            return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
        }
        return `${minutes}:${secs.toString().padStart(2, '0')}`;
    }

    async playVideo(videoId) {
        try {
            const video = this.videos.find(v => v.id === videoId);
            if (!video) return;

            this.showToast('Loading video...', 'info');

            // Get video file from IndexedDB
            const videoFile = await this.getVideoFile(videoId);
            const videoUrl = URL.createObjectURL(videoFile);

            // Increment views
            video.views = (video.views || 0) + 1;
            await this.updateVideoMetadata(video);

            const modal = document.getElementById('playerModal');
            const player = document.getElementById('videoPlayer');
            const titleDisplay = document.getElementById('videoTitleDisplay');
            const descriptionDisplay = document.getElementById('videoDescriptionDisplay');
            const dateDisplay = document.getElementById('videoDateDisplay');
            const sizeDisplay = document.getElementById('videoSizeDisplay');

            player.src = videoUrl;
            titleDisplay.textContent = video.title;
            descriptionDisplay.textContent = video.description || 'Tidak ada deskripsi';
            dateDisplay.innerHTML = `<i class="fas fa-calendar"></i> ${new Date(video.uploadDate).toLocaleDateString('id-ID')}`;
            
            const resolution = video.width && video.height ? ` | ${video.width}x${video.height}` : '';
            sizeDisplay.innerHTML = `<i class="fas fa-hdd"></i> ${this.formatFileSize(video.fileSize)}${resolution} | <i class="fas fa-eye"></i> ${video.views} views`;

            modal.style.display = 'flex';
            this.currentVideo = video;
            this.currentVideoUrl = videoUrl;

        } catch (error) {
            console.error('Error playing video:', error);
            this.showToast('Gagal memutar video: ' + error.message, 'error');
        }
    }

    async updateVideoMetadata(video) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['videos'], 'readwrite');
            const store = transaction.objectStore('videos');
            const request = store.put(video);

            request.onsuccess = () => resolve();
            request.onerror = () => reject(request.error);
        });
    }

    handleSearch() {
        const searchTerm = document.getElementById('searchInput').value.toLowerCase();
        const filteredVideos = this.videos.filter(video => 
            video.title.toLowerCase().includes(searchTerm) || 
            (video.description && video.description.toLowerCase().includes(searchTerm))
        );
        this.renderVideos(filteredVideos);
    }

    handleSort() {
        const sortBy = document.getElementById('sortFilter').value;
        let sortedVideos = [...this.videos];

        switch(sortBy) {
            case 'newest':
                sortedVideos.sort((a, b) => new Date(b.uploadDate) - new Date(a.uploadDate));
                break;
            case 'oldest':
                sortedVideos.sort((a, b) => new Date(a.uploadDate) - new Date(b.uploadDate));
                break;
            case 'title':
                sortedVideos.sort((a, b) => a.title.localeCompare(b.title));
                break;
        }

        this.renderVideos(sortedVideos);
    }

    openUploadModal() {
        document.getElementById('uploadModal').style.display = 'flex';
        document.getElementById('videoTitle').focus();
    }

    closeUploadModal() {
        const modal = document.getElementById('uploadModal');
        const form = document.getElementById('uploadForm');
        const fileInfo = document.getElementById('fileInfo');
        const progressContainer = document.getElementById('uploadProgress');
        const submitBtn = document.querySelector('#uploadForm button[type="submit"]');
        
        modal.style.display = 'none';
        form.reset();
        fileInfo.style.display = 'none';
        progressContainer.style.display = 'none';
        
        // Reset button state
        submitBtn.disabled = false;
        submitBtn.innerHTML = '<i class="fas fa-upload"></i> Upload Video';
    }

    closePlayerModal() {
        const modal = document.getElementById('playerModal');
        const player = document.getElementById('videoPlayer');
        
        modal.style.display = 'none';
        player.pause();
        player.currentTime = 0;
        
        // Clean up object URL
        if (this.currentVideoUrl) {
            URL.revokeObjectURL(this.currentVideoUrl);
            this.currentVideoUrl = null;
        }
        
        this.currentVideo = null;
    }

    async deleteVideo(videoId) {
        if (!confirm('Yakin ingin hapus video ini?')) return;

        try {
            // Delete from IndexedDB
            await Promise.all([
                this.deleteVideoFile(videoId),
                this.deleteVideoMetadata(videoId)
            ]);

            // Remove from local array
            this.videos = this.videos.filter(v => v.id !== videoId);
            
            this.renderVideos();
            this.showToast('Video berhasil dihapus', 'success');

        } catch (error) {
            console.error('Delete error:', error);
            this.showToast('Gagal menghapus video', 'error');
        }
    }

    deleteVideoFile(id) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['videoFiles'], 'readwrite');
            const store = transaction.objectStore('videoFiles');
            const request = store.delete(id);

            request.onsuccess = () => resolve();
            request.onerror = () => reject(request.error);
        });
    }

    deleteVideoMetadata(id) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['videos'], 'readwrite');
            const store = transaction.objectStore('videos');
            const request = store.delete(id);

            request.onsuccess = () => resolve();
            request.onerror = () => reject(request.error);
        });
    }

    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    escapeHtml(text) {
        if (!text) return '';
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    showToast(message, type = 'success') {
        const toast = document.getElementById('toast');
        const icon = toast.querySelector('.toast-icon');
        const messageEl = toast.querySelector('.toast-message');

        toast.className = `toast ${type}`;
        
        let iconClass;
        switch(type) {
            case 'success': iconClass = 'fa-check-circle'; break;
            case 'error': iconClass = 'fa-exclamation-circle'; break;
            case 'info': iconClass = 'fa-info-circle'; break;
            default: iconClass = 'fa-check-circle';
        }
        
        icon.className = `toast-icon fas ${iconClass}`;
        messageEl.textContent = message;

        toast.classList.add('show');

        setTimeout(() => {
            toast.classList.remove('show');
        }, type === 'info' ? 2000 : 4000);
    }
}

// Global functions for onclick handlers
function openUploadModal() {
    videoPlayer.openUploadModal();
}

function closeUploadModal() {
    videoPlayer.closeUploadModal();
}

function closePlayerModal() {
    videoPlayer.closePlayerModal();
}

// Initialize the video player when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.videoPlayer = new VideoPlayer();
});
