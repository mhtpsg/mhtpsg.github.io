// script.js
class KodokersApp {
    constructor() {
        this.hamburger = document.getElementById('hamburger');
        this.closeBtn = document.getElementById('closeBtn');
        this.videoOverlay = document.getElementById('videoOverlay');
        this.videoCards = document.querySelectorAll('.video-card');
        
        this.init();
    }

    init() {
        this.bindEvents();
        this.setupLazyLoading();
    }

    bindEvents() {
        // Menu events
        this.hamburger.addEventListener('click', () => this.openOverlay());
        this.closeBtn.addEventListener('click', () => this.closeOverlay());
        this.videoOverlay.addEventListener('click', (e) => {
            if (e.target === this.videoOverlay) this.closeOverlay();
        });

        // Video events
        this.videoCards.forEach(card => {
            card.addEventListener('click', () => this.openVideo(card.dataset.video));
        });

        // Keyboard events
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') this.closeOverlay();
        });
    }

    openOverlay() {
        this.hamburger.classList.add('active', 'hide');
        this.videoOverlay.classList.add('active');
        this.closeBtn.classList.add('active');
        document.body.style.overflow = 'hidden';
    }

    closeOverlay() {
        this.hamburger.classList.remove('active', 'hide');
        this.videoOverlay.classList.remove('active');
        this.closeBtn.classList.remove('active');
        document.body.style.overflow = 'auto';
    }

    openVideo(videoId) {
        window.open(`https://www.youtube.com/watch?v=${videoId}`, '_blank');
    }

    setupLazyLoading() {
        const imageObserver = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    const img = entry.target;
                    if (img.dataset.src) {
                        img.src = img.dataset.src;
                        img.removeAttribute('data-src');
                        imageObserver.unobserve(img);
                    }
                }
            });
        }, { threshold: 0.1, rootMargin: '50px' });

        document.querySelectorAll('.video-thumb img').forEach(img => {
            imageObserver.observe(img);
        });
    }
}

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new KodokersApp();
});
