class WordExplorer {
    constructor() {
        this.apiUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en/';
        this.currentAudio = null;
        this.searchHistory = this.loadFromStorage('searchHistory') || [];
        this.favorites = this.loadFromStorage('favorites') || [];
        
        // Common words for random selection
        this.commonWords = [
            'serendipity', 'ephemeral', 'mellifluous', 'petrichor', 'aurora',
            'wanderlust', 'euphoria', 'solitude', 'tranquil', 'resilient',
            'eloquent', 'ambitious', 'innovative', 'magnificent', 'brilliant',
            'incredible', 'fascinating', 'extraordinary', 'phenomenal', 'remarkable',
            'adventure', 'beautiful', 'creative', 'determined', 'enthusiastic',
            'grateful', 'harmonious', 'inspiring', 'joyful', 'knowledge',
            'luminous', 'mysterious', 'optimistic', 'peaceful', 'radiant',
            'serene', 'triumphant', 'vivacious', 'wisdom', 'xenial'
        ];
        
        this.initializeEventListeners();
        this.renderHistory();
        this.renderFavorites();
    }

    initializeEventListeners() {
        // Search functionality
        document.getElementById('searchBtn').addEventListener('click', () => this.handleSearch());
        document.getElementById('wordInput').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.handleSearch();
        });

        // Quick actions
        document.getElementById('randomWordBtn').addEventListener('click', () => this.searchRandomWord());
        document.getElementById('clearHistoryBtn').addEventListener('click', () => this.clearHistory());

        // Error handling
        document.getElementById('closeError').addEventListener('click', () => this.hideError());

        // Auto-focus on input
        document.getElementById('wordInput').focus();
    }

    async handleSearch() {
        const word = document.getElementById('wordInput').value.trim().toLowerCase();
        if (!word) {
            this.showError('Please enter a word to search for.');
            return;
        }

        await this.searchWord(word);
    }

    async searchWord(word) {
        try {
            this.showLoading();
            const response = await fetch(`${this.apiUrl}${encodeURIComponent(word)}`);
            
            if (!response.ok) {
                if (response.status === 404) {
                    throw new Error(`Sorry, we couldn't find the word "${word}". Please check the spelling and try again.`);
                } else {
                    throw new Error('Failed to fetch word data. Please try again later.');
                }
            }

            const data = await response.json();
            this.displayWordData(data[0]);
            this.addToHistory(word);
            document.getElementById('wordInput').value = '';
            
        } catch (error) {
            this.showError(error.message);
        } finally {
            this.hideLoading();
        }
    }

    async searchRandomWord() {
        const randomWord = this.commonWords[Math.floor(Math.random() * this.commonWords.length)];
        document.getElementById('wordInput').value = randomWord;
        await this.searchWord(randomWord);
    }

    displayWordData(wordData) {
        const resultsSection = document.getElementById('resultsSection');
        const wordCard = document.getElementById('wordCard');
        
        const word = wordData.word;
        const phonetics = wordData.phonetics || [];
        const meanings = wordData.meanings || [];
        
        // Find phonetic text and audio
        const phoneticText = phonetics.find(p => p.text)?.text || '';
        const audioUrl = phonetics.find(p => p.audio)?.audio || '';

        // Check if word is favorited
        const isFavorited = this.favorites.some(fav => fav.word === word);

        let html = `
            <div class="word-header">
                <div class="word-title">
                    <h2>${word.charAt(0).toUpperCase() + word.slice(1)}</h2>
                    <div class="phonetic-container">
                        ${phoneticText ? `<span class="phonetic">${phoneticText}</span>` : ''}
                        ${audioUrl ? `<button class="audio-btn" onclick="wordExplorer.playAudio('${audioUrl}')">🔊 Listen</button>` : ''}
                    </div>
                </div>
                <button class="favorite-btn ${isFavorited ? 'favorited' : ''}" onclick="wordExplorer.toggleFavorite('${word}', '${phoneticText}', this)">
                    ${isFavorited ? '⭐' : '☆'}
                </button>
            </div>
            <div class="meanings-container">
        `;

        meanings.forEach((meaning, meaningIndex) => {
            const partOfSpeech = meaning.partOfSpeech || 'Unknown';
            const definitions = meaning.definitions || [];
            const synonyms = meaning.synonyms || [];
            const antonyms = meaning.antonyms || [];

            html += `
                <div class="meaning-item">
                    <div class="part-of-speech">${partOfSpeech}</div>
            `;

            definitions.forEach((def, defIndex) => {
                html += `
                    <div class="definition-group">
                        <div class="definition">${defIndex + 1}. ${def.definition}</div>
                        ${def.example ? `<div class="example">"${def.example}"</div>` : ''}
                    </div>
                `;
            });

            if (synonyms.length > 0) {
                html += `
                    <div class="synonyms">
                        <h4>Synonyms:</h4>
                        <div class="synonym-list">
                            ${synonyms.map(syn => `<span class="synonym-item" onclick="wordExplorer.searchWord('${syn}')">${syn}</span>`).join('')}
                        </div>
                    </div>
                `;
            }

            if (antonyms.length > 0) {
                html += `
                    <div class="antonyms">
                        <h4>Antonyms:</h4>
                        <div class="antonym-list">
                            ${antonyms.map(ant => `<span class="antonym-item" onclick="wordExplorer.searchWord('${ant}')">${ant}</span>`).join('')}
                        </div>
                    </div>
                `;
            }

            html += '</div>';
        });

        html += '</div>';
        
        wordCard.innerHTML = html;
        resultsSection.style.display = 'block';
        
        // Smooth scroll to results
        resultsSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }

    playAudio(audioUrl) {
        // Stop any currently playing audio
        if (this.currentAudio) {
            this.currentAudio.pause();
            this.currentAudio.currentTime = 0;
        }

        this.currentAudio = new Audio(audioUrl);
        this.currentAudio.play().catch(error => {
            this.showError('Could not play audio. Audio might not be available.');
        });
    }

    toggleFavorite(word, phonetic, buttonElement) {
        const existingIndex = this.favorites.findIndex(fav => fav.word === word);
        
        if (existingIndex > -1) {
            // Remove from favorites
            this.favorites.splice(existingIndex, 1);
            buttonElement.classList.remove('favorited');
            buttonElement.textContent = '☆';
        } else {
            // Add to favorites
            this.favorites.push({
                word: word,
                phonetic: phonetic,
                timestamp: Date.now()
            });
            buttonElement.classList.add('favorited');
            buttonElement.textContent = '⭐';
        }

        this.saveToStorage('favorites', this.favorites);
        this.renderFavorites();
    }

    addToHistory(word) {
        // Remove word if it already exists
        this.searchHistory = this.searchHistory.filter(item => item.word !== word);
        
        // Add to beginning of array
        this.searchHistory.unshift({
            word: word,
            timestamp: Date.now()
        });

        // Keep only the last 20 searches
        this.searchHistory = this.searchHistory.slice(0, 20);
        
        this.saveToStorage('searchHistory', this.searchHistory);
        this.renderHistory();
    }

    renderHistory() {
        const container = document.getElementById('historyContainer');
        
        if (this.searchHistory.length === 0) {
            container.innerHTML = '<p class="no-history">No words explored yet. Start by searching for a word!</p>';
            return;
        }

        const html = this.searchHistory.map(item => 
            `<span class="history-item" onclick="wordExplorer.searchWord('${item.word}')">${item.word}</span>`
        ).join('');

        container.innerHTML = html;
    }

    renderFavorites() {
        const container = document.getElementById('favoritesContainer');
        
        if (this.favorites.length === 0) {
            container.innerHTML = '<p class="no-favorites">No favorite words yet. Click the star icon on any word to add it to favorites!</p>';
            return;
        }

        const html = this.favorites.map(item => 
            `<span class="favorite-item" onclick="wordExplorer.searchWord('${item.word}')">
                ${item.word}
                <button class="remove-favorite" onclick="event.stopPropagation(); wordExplorer.removeFavorite('${item.word}')">✕</button>
            </span>`
        ).join('');

        container.innerHTML = html;
    }

    removeFavorite(word) {
        this.favorites = this.favorites.filter(fav => fav.word !== word);
        this.saveToStorage('favorites', this.favorites);
        this.renderFavorites();
        
        // Update favorite button if the word is currently displayed
        const favoriteBtn = document.querySelector('.favorite-btn');
        if (favoriteBtn) {
            const currentWord = document.querySelector('.word-title h2')?.textContent?.toLowerCase();
            if (currentWord === word) {
                favoriteBtn.classList.remove('favorited');
                favoriteBtn.textContent = '☆';
            }
        }
    }

    clearHistory() {
        if (this.searchHistory.length === 0) {
            this.showError('No history to clear.');
            return;
        }

        if (confirm('Are you sure you want to clear your search history?')) {
            this.searchHistory = [];
            this.saveToStorage('searchHistory', this.searchHistory);
            this.renderHistory();
        }
    }

    showLoading() {
        document.getElementById('loading').style.display = 'flex';
    }

    hideLoading() {
        document.getElementById('loading').style.display = 'none';
    }

    showError(message) {
        const errorMessage = document.getElementById('errorMessage');
        const errorText = document.getElementById('errorText');
        
        errorText.textContent = message;
        errorMessage.style.display = 'flex';
        
        // Auto-hide after 5 seconds
        setTimeout(() => {
            this.hideError();
        }, 5000);
    }

    hideError() {
        document.getElementById('errorMessage').style.display = 'none';
    }

    saveToStorage(key, data) {
        try {
            localStorage.setItem(key, JSON.stringify(data));
        } catch (error) {
            console.warn('Could not save to localStorage:', error);
        }
    }

    loadFromStorage(key) {
        try {
            const data = localStorage.getItem(key);
            return data ? JSON.parse(data) : null;
        } catch (error) {
            console.warn('Could not load from localStorage:', error);
            return null;
        }
    }
}

// Initialize the application
const wordExplorer = new WordExplorer();

// Service Worker registration for offline functionality (optional)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('./sw.js')
            .then(registration => {
                console.log('SW registered: ', registration);
            })
            .catch(registrationError => {
                console.log('SW registration failed: ', registrationError);
            });
    });
}
