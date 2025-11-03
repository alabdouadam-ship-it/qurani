document.addEventListener("DOMContentLoaded", () => {
    const scrollToTopBtn = document.getElementById("scrollToTopBtn");

    if (!scrollToTopBtn) return;

    window.addEventListener("scroll", () => {
        const tafsirVisible = elements.tafsirPage && elements.tafsirPage.style.display !== 'none';
        const audioVisible = elements.audioPage && elements.audioPage.style.display !== 'none';
        const fullAudioVisible = elements.fullAudioPage && elements.fullAudioPage.style.display !== 'none';
        const tasbeehVisible = elements.tasbeehPage && elements.tasbeehPage.style.display !== 'none';
        const adminVisible = elements.adminPage && elements.adminPage.style.display !== 'none';
        const searchVisible = elements.searchPage && elements.searchPage.style.display !== 'none';
        const hadithVisible = elements.hadithPage && elements.hadithPage.style.display !== 'none';


        if ((tafsirVisible || audioVisible || fullAudioVisible || tasbeehVisible || adminVisible || searchVisible || hadithVisible) && window.scrollY > 300) {
            scrollToTopBtn.style.display = "block";
        } else {
            scrollToTopBtn.style.display = "none";
        }
    });

    scrollToTopBtn.addEventListener("click", () => {
        window.scrollTo({ top: 0, behavior: "smooth" });
    });
});

const tg = window.Telegram.WebApp;

const isTelegram = window.Telegram && window.Telegram.WebApp;

const elements = {
    // Page elements
    loginPage: document.getElementById("login-page"),
    forgotPasswordPage: document.getElementById("forgot-password-page"),
    mainMenuPage: document.getElementById("main-menu-page"),
    gameLobbyPage: document.getElementById("game-lobby-page"),
    gameContainer: document.getElementById("game-container"),
    adminPage: document.getElementById("admin-page"),
    messageForm: document.getElementById("message-form"),
    messageList: document.getElementById("message-list"),
    messageTextInput: document.getElementById("message-text-input"),
    messageTimeInput: document.getElementById("message-time-input"),
    messageIdInput: document.getElementById("message-id-input"),
    searchPage: document.getElementById("search-page"),
    searchInput: document.getElementById("search-input"),
    searchButton: document.getElementById("search-button"),
    searchResultsCount: document.getElementById("search-results-count"),
    searchResultsList: document.getElementById("search-results-list"),
    welcomeMessage: document.getElementById("welcome-message"),
    quranReaderPage: document.getElementById("quran-reader-page"),
    hadithPage: document.getElementById("hadith-page"),


    // Button elements
    loginButton: document.getElementById("login-button"),
    registerButton: document.getElementById("register-button"),
    toggleFormLink: document.getElementById("toggle-form-link"),
    forgotPasswordLink: document.getElementById("forgot-password-link"),
    goToMainFromLoginButton: document.getElementById("go-to-main-from-login-button"),
    forgotPasswordEmail: document.getElementById("forgot-password-email"),
    forgotPasswordName: document.getElementById("forgot-password-name"),
    verifyIdentityButton: document.getElementById("verify-identity-button"),
    verifyIdentityStep: document.getElementById("verify-identity-step"),
    resetPasswordStep: document.getElementById("reset-password-step"),
    newPassword: document.getElementById("new-password"),
    confirmNewPassword: document.getElementById("confirm-new-password"),
    resetPasswordButton: document.getElementById("reset-password-button"),
    backToLoginLink: document.getElementById("back-to-login-link"),
    logoutButton: document.getElementById("logout-button"),
    mainLoginButton: document.getElementById("main-login-button"),
    guestLoginButton: document.getElementById("guest-login-button"),
    guestRegisterLink: document.getElementById("guest-register-link"),
    guestLoginInvitation: document.getElementById("guest-login-invitation"),
    goToReaderButton: document.getElementById("go-to-reader-button"),
    goToGameButton: document.getElementById("go-to-game-button"),
    goToTafsirButton: document.getElementById("go-to-tafsir-button"),
    goToAudioButton: document.getElementById("go-to-audio-button"),
    goToFullAudioButton: document.getElementById("go-to-full-audio-button"),
    goToHadithButton: document.getElementById("go-to-hadith-button"),
    goToTasbeehButton: document.getElementById("go-to-tasbeeh-button"),
    goToAdminButton: document.getElementById("go-to-admin-button"),
    backToMenuFromLobbyButton: document.getElementById("back-to-menu-from-lobby-button"),
    startGameButton: document.getElementById("start-game-button"),
    addMessageBtn: document.getElementById("add-message-btn"),
    saveMessageBtn: document.getElementById("save-message-btn"),
    cancelEditBtn: document.getElementById("cancel-edit-btn"),
    goToSearchButton: document.getElementById("go-to-search-button"),
    backToMenuFromSearch: document.getElementById("back-to-main-menu-from-search"),

    // Privacy Policy Links
    privacyPolicyLinkLogin: document.getElementById("privacy-policy-link-login-btn"),
    privacyPolicyLinkForgot: document.getElementById("privacy-policy-link-forgot-btn"),
    privacyPolicyLinkMenu: document.getElementById("privacy-policy-link-menu-btn"),

    // Form Inputs
    loginUsernameInput: document.getElementById("login-username"),
    loginPasswordInput: document.getElementById("login-password"),
    registerFullNameInput: document.getElementById("register-fullName"),

    // Page containers
    tafsirPage: document.getElementById("tafsir-page"),
    audioPage: document.getElementById("audio-page"),
    fullAudioPage: document.getElementById("full-audio-page"),
    tasbeehPage: document.getElementById("tasbeeh-page"),

    // Audio players
    audioPlayer: document.getElementById("audioPlayer"),
    fullAudioPlayer: document.getElementById("fullAudioPlayer"),

    // Game elements
    score: document.getElementById("score"),
    questionCounter: document.getElementById("question-counter"),
    questionTimer: document.getElementById("question-timer"),
    progressBar: document.getElementById("progress-bar"),
    questionText: document.getElementById("question-text"),
    optionsContainer: document.getElementById("options-container"),
    result: document.getElementById("result"),
    
    // Tab elements
    tabButtons: document.querySelectorAll('.tab-button'),
    surahTab: document.getElementById('surah-tab'),
    juzTab: document.getElementById('juz-tab'),
    juzSelect: document.getElementById('juz-select'),
    
    categorySelect: document.getElementById("category-select"),
    pauseButton: document.getElementById("pause-button"),
    pauseOverlay: document.getElementById("pause-overlay"),
    resumeButton: document.getElementById("resume-button"),
    endGameButton: document.getElementById("end-game-button"),
    totalScoreMain: document.getElementById("total-score-main"),
    totalScoreGame: document.getElementById("total-score-game"),
    confirmEndOverlay: document.getElementById("confirm-end-overlay"),
    confirmEndYes: document.getElementById("confirm-end-yes"),
    confirmEndNo: document.getElementById("confirm-end-no"),
    leaderboardSection: document.getElementById("leaderboard-section"),
    leaderboardList: document.getElementById("leaderboard-list"),
    showOnLeaderboardCheckbox: document.getElementById("show-on-leaderboard-checkbox"),
    floatingMessage: document.getElementById("floating-message"),

    // Go to page modal elements
    goToPageOverlay: document.getElementById("goto-page-overlay"),
    goToPageInput: document.getElementById("goto-page-input"),
    goToPageConfirmBtn: document.getElementById("goto-page-confirm"),
    goToPageCancelBtn: document.getElementById("goto-page-cancel"),
    
    // Go to surah modal elements
    goToSurahOverlay: document.getElementById("goto-surah-overlay"),
    goToSurahInput: document.getElementById("goto-surah-input"),
    goToSurahList: document.getElementById("goto-surah-list"),
    goToSurahCancelBtn: document.getElementById("goto-surah-cancel"),

    // Go to juz modal elements
    goToJuzOverlay: document.getElementById("goto-juz-overlay"),
    goToJuzList: document.getElementById("goto-juz-list"),
    goToJuzCancelBtn: document.getElementById("goto-juz-cancel"),

    // START: Share Modal elements
    shareModalOverlay: document.getElementById("share-modal-overlay"),
    shareUrlInput: document.getElementById("share-url-input"),
    copyShareUrlBtn: document.getElementById("copy-share-url-btn"),
    closeShareModalBtn: document.getElementById("close-share-modal-btn"),
    shareWhatsapp: document.getElementById("share-whatsapp"),
    shareTelegram: document.getElementById("share-telegram"),
    shareTwitter: document.getElementById("share-twitter"),
    shareFacebook: document.getElementById("share-facebook"),
    // END: Share Modal elements
    
    // Recitation Part
    
    recitationPage: document.getElementById("recitation-page"),
    goToRecitationButton: document.getElementById("go-to-recitation-button"),
    recitationSurahSearchInput: document.getElementById("recitation-surah-search-input"),
    recitationSurahListContainer: document.getElementById("recitation-surah-list-container"),
    verseSelectionPanel: document.getElementById("verse-selection-panel"),
    selectedSurahInfo: document.getElementById("selected-surah-info"),
    startVerseInput: document.getElementById("start-verse-input"),
    endVerseInput: document.getElementById("end-verse-input"),
    startVerseSlider: document.getElementById("start-verse-slider"),
    endVerseSlider: document.getElementById("end-verse-slider"),
    startRecitationBtn: document.getElementById("start-recitation-btn"),
    backToRecitationSelection: document.getElementById("back-to-recitation-selection"),
    recitationTestPanel: document.getElementById("recitation-test-panel"),
    recitationVersesDisplay: document.getElementById("recitation-verses-display"),
    recordBtn: document.getElementById("record-btn"),
    recitationTestResults: document.getElementById("recitation-test-results"),
    recitationAccuracy: document.getElementById("recitation-accuracy"),
    recitationComparisonResults: document.getElementById("recitation-comparison-results"),
    // Add the new playback button element
    playBackBtn: document.getElementById("play-back-btn"),
};

function showPage(pageId) {
    elements.loginPage.style.display = 'none';
    elements.forgotPasswordPage.style.display = 'none';
    elements.mainMenuPage.style.display = 'none';
    elements.gameLobbyPage.style.display = 'none';
    elements.gameContainer.style.display = 'none';
    elements.tafsirPage.style.display = 'none';
    elements.audioPage.style.display = 'none';
    elements.fullAudioPage.style.display = 'none';
    elements.tasbeehPage.style.display = 'none';
    elements.adminPage.style.display = 'none';
    elements.recitationPage.style.display = 'none';
    elements.searchPage.style.display = 'none';
    elements.quranReaderPage.style.display = 'none';
    elements.hadithPage.style.display = 'none';
    if (elements.goToJuzOverlay) elements.goToJuzOverlay.style.display = 'none';

    // --- DYNAMIC WIDTH LOGIC ---
    const container = document.querySelector('.container');
    if (container && !isTelegram) {
        const widePages = ['login-page', 'forgot-password-page', 'game-container', 'tafsir-page', 'audio-page', 'full-audio-page', 'tasbeeh-page', 'admin-page', 'recitation-page', 'search-page', 'quran-reader-page', 'hadith-page'];
        if (widePages.includes(pageId)) {
            container.classList.add('container-wide');
        } else {
            container.classList.remove('container-wide');
        }
    }
    // --- END DYNAMIC WIDTH LOGIC ---

    elements.audioPlayer.pause();
    elements.fullAudioPlayer.pause();
    if ('speechSynthesis' in window) {
        window.speechSynthesis.cancel();
    }

    const page = document.getElementById(pageId);
    if (page) {
        page.style.display = 'block';
    }
    
    window.scrollTo(0, 0);
}

let state = {
    webUserId: null, // For web user session
    isGuest: false, // MODIFIED: To track guest users on web
    questions: [],
    gameId: null,
    currentQuestion: 0,
    score: 0,
    totalScore: 0,
    correctAnswers: 0,
    questionTimerInterval: null,
    isGameFinished: false,
    surahs: [],
    juz: [],
    verses: [],
    selectedSurah: null,
    selectedJuz: null,
    selectedTafsir: null,
    selectedTafsirName: null,
    selectedReciter: null,
    selectedSurahOrder: null,
    surahListPage: 0,
    verseStates: {},
    tasbeehSessionCounts: {},
    currentGameType: 'surah',
    searchResults: [],
    searchExpandedState: {},
    currentQuranPage: 1,
    // Hadith State
    hadithBooks: [],
    currentHadithBook: null,
    hadithsInCurrentBook: [],
    currentHadithIndex: 0,
    // Recitation
    recitation: {
        selectedSurah: null,
        totalVerses: 0,
        startVerse: 1,
        endVerse: 1,
        versesToTest: [],
    },
    recitationAudioRecorder: null,
    recitationAudioChunks: [],
    recordedAudioBlob: null, // Store the recorded audio blob
    mediaStream: null, // To keep track of the microphone stream
};

const TIME_LIMIT = 60;
let timeLeft = TIME_LIMIT;
const SURAHS_PER_PAGE = 114;
const TOTAL_QURAN_PAGES = 604;

const Hadith_Books_Ar = {
    "Sahih Bukhari": "صحيح البخاري",
    "Sahih Muslim": "صحيح مسلم",
    "Jami' Al-Tirmidhi": "جامع الترمذي",
    "Sunan Abu Dawood": "سنن أبو داوود",
    "Sunan Ibn-e-Majah": "سنن ابن ماجه",
    "Sunan An-Nasa`i": "سنن النسائي",
    "Mishkat Al-Masabih": "مشكاة المصابيح",
    "alnawawiforty": "الأربعون النووية",
    "": "",
    "": ""
};
const Hadith_Books_En = {
    "Sahih Bukhari": "Bukhari",
    "Sahih Muslim": "Muslim",
    "Jami' Al-Tirmidhi": "Al-Tirmidhi",
    "Sunan Abu Dawood": "Abu-Dawood",
    "Sunan Ibn-e-Majah": "Ibn-e-Majah",
    "Sunan An-Nasa`i": "An-Nasai",
    "Mishkat Al-Masabih": "Al-Masabih",
    "alnawawiforty": "alnawawiforty",
    "": "",
    "": ""
};
const SURAH_START_PAGES = {
    1: 1, 2: 2, 3: 50, 4: 77, 5: 106, 6: 128, 7: 151, 8: 177, 9: 187, 10: 208,
    11: 221, 12: 235, 13: 249, 14: 255, 15: 262, 16: 267, 17: 282, 18: 293, 19: 305,
    20: 312, 21: 322, 22: 332, 23: 342, 24: 350, 25: 359, 26: 367, 27: 377, 28: 385,
    29: 396, 30: 404, 31: 411, 32: 415, 33: 418, 34: 428, 35: 434, 36: 440, 37: 446,
    38: 453, 39: 458, 40: 467, 41: 477, 42: 483, 43: 489, 44: 496, 45: 499, 46: 502,
    47: 507, 48: 511, 49: 515, 50: 518, 51: 520, 52: 523, 53: 526, 54: 528, 55: 531,
    56: 534, 57: 537, 58: 542, 59: 545, 60: 549, 61: 551, 62: 553, 63: 554, 64: 556,
    65: 558, 66: 560, 67: 562, 68: 564, 69: 566, 70: 568, 71: 570, 72: 572, 73: 574,
    74: 575, 75: 577, 76: 578, 77: 580, 78: 582, 79: 583, 80: 585, 81: 586, 82: 587,
    83: 587, 84: 589, 85: 590, 86: 591, 87: 591, 88: 592, 89: 593, 90: 594, 91: 595,
    92: 595, 93: 596, 94: 596, 95: 597, 96: 597, 97: 598, 98: 598, 99: 599, 100: 599,
    101: 600, 102: 600, 103: 601, 104: 601, 105: 601, 106: 602, 107: 602, 108: 602,
    109: 603, 110: 603, 111: 603, 112: 604, 113: 604, 114: 604
};

const JUZ_START_PAGES = {
    1: 1, 2: 22, 3: 42, 4: 62, 5: 82, 6: 102, 7: 121, 8: 142, 9: 162, 10: 182,
    11: 201, 12: 222, 13: 242, 14: 262, 15: 282, 16: 302, 17: 322, 18: 342, 19: 362,
    20: 382, 21: 402, 22: 422, 23: 442, 24: 462, 25: 482, 26: 502, 27: 522, 28: 542,
    29: 562, 30: 582
};

const TAFSIR_OPTIONS = {
    "الميسر": "muyassar",
    "الميسر الصوتي": "/data/muyassar_audio",
    "البغوي": "baghawi",
    "الجلالين": "jalalayn",
    "ابن عباس": "miqbas",
    "القرطبي": "qurtubi",
    "الوسيط": "waseet"
};
const AUDIO_OPTIONS = {
    "عبدالباسط عبدالصمد": "/data/ayahs/basit",
    "العفاسي": "/data/ayahs/afs",
    "عبدالرحمن السديس": "/data/ayahs/sds",
    "فارس عباد": "/data/ayahs/frs_a",
    "الحصري": "/data/ayahs/husr",
    "المنشاوي": "/data/ayahs/minsh",
    "أيمن سويد": "/data/ayahs/suwaid",
    "عربي - انكليزي": "/data/ayahs/arabic-english",
    "عربي - فرنسي": "/data/ayahs/arabic-french"
};
const FULL_AUDIO_OPTIONS = {
    "عبدالباسط عبدالصمد": "/data/full/basit",
    "العفاسي": "/data/full/afs",
    "عبدالرحمن السديس": "/data/full/sds",
    "فارس عباد": "/data/full/frs_a",
    "الحصري": "/data/full/husr",
    "المنشاوي": "/data/full/minsh",
    "أيمن سويد": "/data/full/suwaid",
    "تفسير الميسر": "/data/muyassar_audio/full"
};

function showFloatingMessage(message, isSuccess = true) {
    const floatingMessage = elements.floatingMessage;
    floatingMessage.textContent = message;
    floatingMessage.className = 'toast-message'; 
    floatingMessage.classList.add('show');
    if (isSuccess) {
        floatingMessage.classList.add('success');
    } else {
        floatingMessage.classList.add('error');
    }
    setTimeout(() => {
        floatingMessage.classList.remove('show');
    }, 3000); 
}

function updateTotalScoreDisplay(score) {
    state.totalScore = score;
    elements.totalScoreMain.textContent = score;
    elements.totalScoreGame.textContent = score;
}

async function apiRequest(endpoint, options = {}) {
    const BASE_URL = "/api";
    try {
        const headers = {
            'Content-Type': 'application/json',
            ...options.headers,
        };

        // قائمة واحدة وواضحة بكل النقاط العامة التي لا تحتاج لمصادقة
        const publicEndpoints = [
            '/health', '/leaderboard', '/surahs', '/juz', '/search', 
            '/register', '/login', '/verify-identity', '/reset-password', '/hadith/books', '/hadith/chapters', 
            '/hadith/search', '/hadith/get-by-number', '/quran/page',
            '/verses', '/tafsir', '/reciters', '/audio'
        ];
        
        // التحقق إذا كان الطلب عاماً أم لا
        const isPublic = publicEndpoints.some(p => endpoint.startsWith(p));

        // إذا لم يكن الطلب عاماً، فهو محمي ويحتاج هيدر مصادقة
        if (!isPublic) {
            if (state.webUserId) {
                headers['X-Web-User-ID'] = state.webUserId;
            } else if (isTelegram && tg.initData) {
                headers['Telegram-Init-Data'] = tg.initData;
            } else {
                // هذا يعني أننا نحاول الوصول لنقطة محمية بدون تسجيل دخول
                // الخادم سيعالج هذا الخطأ ويرجع 401/403
                console.warn(`Attempting to access protected endpoint "${endpoint}" without authentication.`);
            }
        }

        const response = await fetch(`${BASE_URL}${endpoint}`, { ...options, headers });

        if (!response.ok) {
            let errorMessage = `Network response was not ok (${response.status})`;
            try {
                const errorData = await response.json();
                errorMessage = errorData.error || errorMessage;
            } catch (jsonError) {
                // If JSON parsing fails, provide a more helpful error message
                if (isTelegram && tg.initData) {
                    errorMessage = `Server error (${response.status}). Telegram authentication may not be properly configured.`;
                } else {
                    errorMessage = 'فشل تحليل الاستجابة كـ JSON';
                }
            }
            const error = new Error(errorMessage);
            error.status = response.status;
            throw error;
        }

        const contentType = response.headers.get("content-type");
        if (contentType && contentType.indexOf("application/json") !== -1) {
            return response.json();
        }

        return null;

    } catch (error) {
        console.error(`API Request Failed to ${endpoint}:`, error);
        throw error;
    }
}      
// function to render the initial recitation page
async function renderRecitationPage() {
    elements.recitationSurahListContainer.innerHTML = `<p style="text-align:center;">جاري تحميل السور...</p>`;
    elements.verseSelectionPanel.style.display = 'none';
    elements.recitationTestPanel.style.display = 'none';
    elements.recitationTestResults.style.display = 'none'; 
    elements.recitationVersesDisplay.style.display = 'block'; 

    if (state.surahs.length === 0) {
        try {
            const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
            console.log(`🔄 Loading surahs for recitation page, language: ${currentLanguage}`);
            const surahs = await loadSurahData(currentLanguage);
            if (surahs && surahs.length > 0) {
            state.surahs = surahs;
                console.log(`✅ Loaded ${surahs.length} surahs for recitation page`);
            } else {
                throw new Error('No surahs loaded');
            }
        } catch (e) {
            console.error('❌ Error loading surahs:', e);
            const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
            const translations = window.translations && window.translations[currentLanguage] || window.translations?.ar || {};
            showFloatingMessage(translations['loading-surahs'] || "فشل تحميل قائمة السور.", false);
            elements.recitationSurahListContainer.innerHTML = `<p style="text-align:center; color:red;">${translations['loading-surahs-failed'] || 'للأسف فشل تحميل السور.'}</p>`;
            return;
        }
    }
    
    elements.recitationSurahSearchInput.style.display = 'block';
    elements.recitationSurahListContainer.style.display = ''; // <-- هذا هو السطر المضاف لإظهار القائمة
    
    // Apply translations to the loading message
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const translations = window.translations && window.translations[currentLanguage] || window.translations?.ar || {};
    const loadingElement = elements.recitationSurahListContainer.querySelector('[data-translate="loading-surahs"]');
    if (loadingElement) {
        loadingElement.textContent = translations['loading-surahs'] || 'جاري تحميل السور...';
    }
    
    elements.recitationSurahListContainer.innerHTML = generateSurahButtonsHTML(state.surahs);
}

// Helper function to load and display leaderboard
async function loadLeaderboard() {
    try {
        console.log('Loading leaderboard...');
        const leaderboardResult = await apiRequest('/leaderboard');
        console.log('Leaderboard API response:', leaderboardResult);
        
        if (leaderboardResult) {
            const players = leaderboardResult;
            console.log('Players data:', players);
            elements.leaderboardList.innerHTML = '';
            if (players && players.length > 0) {
                players.forEach((player, index) => {
                    const rank = index + 1;
                    const li = document.createElement('li');
                    li.classList.add(`rank-${rank}`);

                    let rankDisplay;
                    if (rank === 1) rankDisplay = '🥇';
                    else if (rank === 2) rankDisplay = '🥈';
                    else if (rank === 3) rankDisplay = '🥉';
                    else rankDisplay = rank;

                    li.innerHTML = `
                        <span class="rank rank-badge">${rankDisplay}</span>
                        <span class="player-name">${player.UserFullName || 'لاعب غير معروف'}</span>
                        <span class="player-score">${player.TotalScore}</span>
                    `;
                    elements.leaderboardList.appendChild(li);
                });
                console.log('Leaderboard loaded successfully with', players.length, 'players');
            } else {
                elements.leaderboardList.innerHTML = '<li>لا يوجد لاعبون في القائمة بعد.</li>';
                console.log('Leaderboard is empty');
            }
        } else {
            elements.leaderboardList.innerHTML = '<li>لا يمكن تحميل القائمة حالياً.</li>';
            console.log('Leaderboard result is null');
        }
    } catch (error) {
        console.error("Error loading leaderboard:", error);
        console.error("Error details:", error.message);
        elements.leaderboardList.innerHTML = '<li>لا يمكن تحميل القائمة حالياً.</li>';
    }
}

async function loadInitialData() {
    elements.totalScoreMain.textContent = 'جاري التحميل...';
    elements.leaderboardList.innerHTML = '<li>جاري تحميل القائمة...</li>';

    console.log('loadInitialData called, state.isGuest:', state.isGuest);
    
    try {

        // For guests, don't load leaderboard since they can't see it
        if (state.isGuest && !(window.Telegram && window.Telegram.WebApp)) {
            console.log('Loading data for guest user - skipping leaderboard');
            elements.totalScoreMain.textContent = 'سجل دخولك لرؤية نقاطك';
            elements.leaderboardList.innerHTML = '<li>سجل دخولك لرؤية قائمة المتصدرين</li>';
            // Show hadith button for guests too
            elements.goToHadithButton.style.display = 'flex';
            return;
        }
        // For logged-in users, load full data
        console.log('Loading data for authenticated user...');
        const [userDataResult, leaderboardResult] = await Promise.allSettled([
            apiRequest('/user-data'),
            apiRequest('/leaderboard')
        ]);
        
        console.log('User data result:', userDataResult.status);
        console.log('Leaderboard result:', leaderboardResult.status);
        
        // Debug: Check if we have web user ID
        console.log('Web user ID:', state.webUserId);
        console.log('Is guest:', state.isGuest);
        console.log('Is Telegram:', isTelegram);
        if (userDataResult.status === 'rejected') {
            const error = userDataResult.reason;
            elements.totalScoreMain.textContent = 'فشل التحميل';
            console.error("User data error:", error);
            
            // For Telegram users, handle authentication errors more gracefully
            if (isTelegram && tg.initData) {
                console.log("Telegram user authentication failed, treating as authenticated with full access");
                state.isGuest = false; // Keep as authenticated for UI purposes
                elements.totalScoreMain.textContent = 'مرحباً بك في تطبيق قرآني!';
                updateUIForUserStatus();
                // Don't show error message for Telegram users, just continue
                console.log("Continuing with app functionality for Telegram user despite user data error");
                
                // Load leaderboard for Telegram users even when user data fails
                await loadLeaderboard();
                
                // Show hadith button for Telegram users
                elements.goToHadithButton.style.display = 'flex';
                return; // Skip the rest of the function
            } else {
                let message = `فشل تحميل بيانات المستخدم: ${error.message}`;
                if (error.status === 403) {
                    message = translations['auth-verification-failed'] || "فشل التحقق من المصادقة. يرجى إعادة تسجيل الدخول.";
                    handleLogout();
                } else if (error.status === 401) {
                    // Authentication failed, treat as guest
                    state.isGuest = true;
                    elements.totalScoreMain.textContent = 'سجل دخولك لرؤية نقاطك';
                    updateUIForUserStatus();
                    return; // Skip the rest of the function for guests
                }
                showFloatingMessage(message, false);
                return;
            }
        } else if (userDataResult.value) {
            // User is successfully authenticated, update guest status
            state.isGuest = false;
            updateTotalScoreDisplay(userDataResult.value.TotalScore);
            if (elements.showOnLeaderboardCheckbox) {
                elements.showOnLeaderboardCheckbox.checked = userDataResult.value.ShowOnLeaderboard;
            }
            if (elements.welcomeMessage && userDataResult.value.UserFullName) {
                const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
                const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
                elements.welcomeMessage.textContent = `${translations['welcome'] || 'أهلاً بك'}، ${userDataResult.value.UserFullName}! 👋`;
            }
        }
        elements.goToHadithButton.style.display = 'flex';

        const isAdminResult = await apiRequest('/admin/is-admin');
        //alert('HELLO');
        if (isAdminResult && isAdminResult.is_admin) {
            elements.goToAdminButton.style.display = 'flex';
        } else {
            elements.goToAdminButton.style.display = 'none';
        }

        const isSuperResult = await apiRequest('/user/status');
        
        // إخفاء خاصية التسميع بشكل كامل - تم تعطيلها مؤقتاً
        elements.goToRecitationButton.style.display = 'none';
        
        // الكود الأصلي - معطل مؤقتاً لإخفاء خاصية التسميع
        // if (isSuperResult && isSuperResult.is_super_user) {
        //     elements.goToRecitationButton.style.display = 'flex';
        // } else {
        //     elements.goToRecitationButton.style.display = 'none';
        // }

        if (leaderboardResult.status === 'rejected') {
            elements.leaderboardList.innerHTML = '<li>فشل تحميل القائمة.</li>';
            console.error("Leaderboard error:", leaderboardResult.reason);
            console.error("Leaderboard error details:", leaderboardResult.reason.message);
        } else if (leaderboardResult.value) {
            const players = leaderboardResult.value;
            console.log('Leaderboard data received:', players);
            elements.leaderboardList.innerHTML = '';
            if (players && players.length > 0) {
                players.forEach((player, index) => {
                    const rank = index + 1;
                    const li = document.createElement('li');
                    li.classList.add(`rank-${rank}`);

                    let rankDisplay;
                    if (rank === 1) rankDisplay = '🥇';
                    else if (rank === 2) rankDisplay = '🥈';
                    else if (rank === 3) rankDisplay = '🥉';
                    else rankDisplay = rank;

                    li.innerHTML = `
                        <span class="rank rank-badge">${rankDisplay}</span>
                        <span class="player-name">${player.UserFullName || 'لاعب غير معروف'}</span>
                        <span class="player-score">${player.TotalScore}</span>
                    `;
                    elements.leaderboardList.appendChild(li);
                });
                console.log('Leaderboard loaded successfully with', players.length, 'players');
            } else {
                elements.leaderboardList.innerHTML = '<li>لا يوجد لاعبون في القائمة بعد.</li>';
                console.log('Leaderboard is empty');
            }
        } else {
            // If leaderboard result is null, try to load it separately
            console.log('Leaderboard result is null, trying to load separately...');
            await loadLeaderboard();
        }
    } catch (error) {
         const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
         const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
         //showFloatingMessage(translations['initial-data-load-error'] || "حدث خطأ أثناء تحميل البيانات الأولية. يرجى المحاولة مرة أخرى.", false);
         console.error("Error in loadInitialData:", error);
    }
}

async function loadSurahOptions() {
    try {
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        
        // Use existing surahs if already loaded, otherwise load them
        let categories = state.surahs;
        if (!categories || categories.length === 0) {
            console.log('🔄 Loading surahs in loadSurahOptions...');
            categories = await loadSurahData(currentLanguage);
        } else {
            console.log(`✅ Using existing ${categories.length} surahs in loadSurahOptions`);
        }
        
        const selectElement = elements.categorySelect;
        state.surahs = categories; // This will now contain start_page assuming the API provides it
        const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
        selectElement.innerHTML = `<option value="all">${translations['all-surahs'] || 'كل السور'}</option>`;

        if (categories && categories.length > 0) {
            categories.forEach(category => {
                const option = document.createElement('option');
                option.value = category.surah_name;
                option.textContent = category.surah_name;
                selectElement.appendChild(option);
            });
        }
    } catch (error) {
        console.error("Failed to load surahs:", error);
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
        showFloatingMessage(translations['loading-surahs'] || "فشل تحميل قائمة السور.", false);
    }
}

async function initializeGame() {
    elements.startGameButton.disabled = true;
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
    elements.startGameButton.textContent = translations['starting-questions'] || 'جاري البدء بعرض الأسئلة...';
    
    let gameIdentifier = null;
    let gameType = state.currentGameType;

    if (gameType === 'surah') {
        gameIdentifier = elements.categorySelect.value;
        if (gameIdentifier === 'all') {
            gameType = 'all'; 
        }
    } else if (gameType === 'juz') {
        gameIdentifier = elements.juzSelect.value;
        if (!gameIdentifier) {
            showFloatingMessage(translations['please-choose-part'] || "الرجاء اختيار جزء أولاً.", false);
            elements.startGameButton.disabled = false;
            elements.startGameButton.textContent = `🚀 ${translations['start-questions'] || 'ابدأ الأسئلة'}`;
            return;
        }
    }
    
    if (!gameIdentifier && gameType !== 'all') {
        showFloatingMessage(translations['please-choose-test-type'] || "الرجاء اختيار نوع الاختبار.", false);
        elements.startGameButton.disabled = false;
        elements.startGameButton.textContent = `🚀 ${translations['start-questions'] || 'ابدأ الأسئلة'}`;
        return;
    }

    try {
        const sessionData = await apiRequest('/start-game', { method: 'POST' });
        state.gameId = sessionData.game_id;

        if (!state.gameId) throw new Error(translations['failed-get-game-id'] || "لم يتم الحصول على معرّف للجولة.");

        // Convert Latin surah name to Arabic for backend
        const backendIdentifier = (gameType === 'surah' && gameIdentifier !== 'all') 
            ? getArabicSurahName(gameIdentifier) 
            : gameIdentifier;
        
        // Debug logging
        console.log('🔍 Game initialization debug:');
        console.log('  gameType:', gameType);
        console.log('  gameIdentifier:', gameIdentifier);
        console.log('  backendIdentifier:', backendIdentifier);
        console.log('  Encoded identifier:', encodeURIComponent(backendIdentifier || ''));
        
        const questionsData = await apiRequest(`/questions?type=${gameType}&identifier=${encodeURIComponent(backendIdentifier || '')}`);
        const fetchedQuestions = questionsData.questions;

        if (!fetchedQuestions || fetchedQuestions.length === 0) {
            showFloatingMessage(translations['no-questions-available'] || "لا توجد أسئلة متاحة لهذا التصنيف حاليًا.", false);
            throw new Error("No questions available.");
        }

        state.score = 0;
        state.correctAnswers = 0;
        state.currentQuestion = 0;
        state.isGameFinished = false;
        elements.score.textContent = 0;

        state.questions = fetchedQuestions.map(q => ({
            id: q.question_id,
            text: q.text,
            options: q.choices.map(c => c.text),
            correctIndex: q.choices.findIndex(c => c.is_correct)
        }));

        showPage('game-container');
        if(isTelegram) tg.BackButton.show();
        showQuestion();

    } catch (error) {
        console.error("Failed to initialize game:", error);
        showFloatingMessage(`فشل بدء عرض الأسئلة: ${error.message}`, false);
    } finally {
        elements.startGameButton.disabled = false;
        elements.startGameButton.textContent = `🚀 ${translations['start-questions'] || 'ابدأ الأسئلة'}`;
    }
}

function pauseGame() {
    clearInterval(state.questionTimerInterval);
    elements.pauseOverlay.style.display = 'flex';
}

function resumeGame() {
    elements.pauseOverlay.style.display = 'none';
    startQuestionTimer(timeLeft);
}

async function checkAudioFileExists(url) {
    try {
        const response = await fetch(url, { method: 'HEAD' });
        return response.ok;
    } catch (error) {
        console.error("Network error while checking for audio file:", error);
        return false;
    }
}
function getAudioDuration(url) {
    return new Promise((resolve) => {
        const tempAudio = document.createElement('audio');
        tempAudio.onloadedmetadata = () => {
            resolve(tempAudio.duration);
        };
        tempAudio.onerror = () => {
            console.error(`Could not load audio metadata for: ${url}`);
            resolve(0);
        };
        tempAudio.src = url;
    });
}

async function showQuestion() {
    if (state.currentQuestion >= state.questions.length) {
        showEndMessage();
        return;
    }

    elements.audioPlayer.pause();
    elements.audioPlayer.currentTime = 0;
    
    updateProgressBar();
    
    const q = state.questions[state.currentQuestion];
    elements.questionCounter.textContent = `${state.currentQuestion + 1} / ${state.questions.length}`;
    elements.questionText.textContent = q.text;
    elements.optionsContainer.innerHTML = "";
    q.options.forEach((option, index) => {
        const btn = document.createElement("button");
        btn.textContent = option;
        btn.addEventListener("click", () => handleAnswer(btn, index, q.correctIndex));
        elements.optionsContainer.appendChild(btn);
    });

    const audioButton = document.getElementById('play-question-audio-btn');
    const audioSrc = `/data/questions_audio/${q.id}.mp3`;
    let timeForQuestion = 60; 

    const fileExists = await checkAudioFileExists(audioSrc);

    if (fileExists) {
        audioButton.style.display = 'flex';
        audioButton.classList.remove('playing');
        audioButton.innerHTML = '🔊';
        
        const audioDuration = await getAudioDuration(audioSrc);
        if (audioDuration > 0) {
            const calculatedTime = Math.ceil(audioDuration) + 20;
            timeForQuestion = Math.max(60, calculatedTime);
        }

        audioButton.onclick = (event) => {
            event.stopPropagation();
            if (elements.audioPlayer.src.endsWith(audioSrc) && !elements.audioPlayer.paused) {
                elements.audioPlayer.pause();
            } else {
                elements.audioPlayer.src = audioSrc;
                elements.audioPlayer.play().catch(e => {
                    showFloatingMessage(`Error: Playback failed. ${e}`, false);
                });
            }
        };
        
        elements.audioPlayer.onplay = () => {};
        elements.audioPlayer.onpause = elements.audioPlayer.onended = () => {};

    } else {
        audioButton.style.display = 'none';
        audioButton.onclick = null;
    }

    startQuestionTimer(timeForQuestion);
}
const Level_depth = 10
function handleAnswer(selectedButton, selectedIndex, correctIndex) {
    clearInterval(state.questionTimerInterval);
    elements.audioPlayer.pause(); 
    elements.optionsContainer.querySelectorAll("button").forEach(b => b.disabled = true);
    const isCorrect = selectedIndex === correctIndex;
    if (isCorrect) {
        selectedButton.classList.add("correct");
        state.score += (Math.floor(state.correctAnswers/Level_depth) + 1) * 10;
        state.correctAnswers++;
        elements.score.textContent = state.score;
    } else {
        if (selectedButton) selectedButton.classList.add("wrong");
        const correctBtn = elements.optionsContainer.querySelectorAll("button")[correctIndex];
        if (correctBtn) correctBtn.classList.add("correct");
    }
    setTimeout(() => {
        state.currentQuestion++;
        showQuestion();
    }, isCorrect ? 1000 : 2500);
}

function startQuestionTimer(duration) {
    clearInterval(state.questionTimerInterval);
    timeLeft = duration;
    elements.questionTimer.textContent = `⏳ ${timeLeft}`;
    state.questionTimerInterval = setInterval(() => {
        timeLeft--;
        elements.questionTimer.textContent = `⏳ ${timeLeft}`;
        if (timeLeft <= 0) {
            clearInterval(state.questionTimerInterval);
            const q = state.questions[state.currentQuestion];
            handleAnswer(null, -1, q ? q.correctIndex : -1);
        }
    }, 1000);
}

function updateProgressBar() {
    const progress = ((state.currentQuestion + 1) / state.questions.length) * 100;
    elements.progressBar.style.width = `${progress}%`;
}

async function showEndMessage() {
    if (state.isGameFinished) return;
    state.isGameFinished = true;

    clearInterval(state.questionTimerInterval);
    if(isTelegram) tg.BackButton.hide();

    elements.gameContainer.style.display = 'none';

    const incorrectAnswers = state.questions.length - state.correctAnswers;
    let finalTotalScore = state.totalScore;

    try {
        const response = await apiRequest('/end-game', {
            method: 'POST',
            body: JSON.stringify({
                gameId: state.gameId,
                score: state.score,
                correct: state.correctAnswers,
                incorrect: incorrectAnswers
            })
        });
        finalTotalScore = response.new_total_score;
    } catch (error) {
        console.error("Failed to update score:", error);
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
        showFloatingMessage(translations['failed-update-result'] || "فشل تحديث النتيجة النهائية.", false);
        finalTotalScore = state.totalScore + state.score;
    }

    updateTotalScoreDisplay(finalTotalScore);

    elements.gameLobbyPage.style.display = 'block';
    elements.result.style.display = 'block';
    elements.leaderboardSection.style.display = 'block';
    elements.confirmEndOverlay.style.display = 'none';
    
    document.querySelector('.tab-menu').style.display = 'none';
    document.getElementById('surah-tab').style.display = 'none';
    document.getElementById('juz-tab').style.display = 'none';
    document.getElementById('start-game-button').style.display = 'none';
    document.getElementById('total-score-display').style.display = 'none';

    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};

    elements.result.innerHTML = `
        <h2>${translations['questions-ended'] || 'انتهت الأسئلة!'}</h2>
        <p>${translations['final-result'] || 'هذه هي نتيجتك النهائية:'}</p>
        <div style="text-align: right; display: inline-block; margin-top: 1rem; line-height: 2;">
            📝 ${translations['total-questions'] || 'إجمالي الأسئلة'}: <strong>${state.questions.length}</strong><br>
            ✅ ${translations['correct-answers'] || 'الإجابات الصحيحة'}: <strong>${state.correctAnswers}</strong><br>
            ❌ ${translations['wrong-answers'] || 'الإجابات الخاطئة'}: <strong>${incorrectAnswers}</strong><br>
            <hr style="margin: 10px 0;">
            🏆 ${translations['round-score'] || 'نتيجتك في هذه الجولة'}: <strong>${state.score}</strong> ${translations['points'] || 'نقطة'}<br>
            🌟 ${translations['total-balance'] || 'رصيدك الإجمالي'}: <strong>${finalTotalScore}</strong> ${translations['points'] || 'نقطة'}
        </div>
        <div class="end-game-buttons">
            <button id="play-again-button" class="menu-button">🎮 ${translations['another-round'] || 'جولة أخرى من الأسئلة'}</button>
            <button id="return-to-menu-button" class="menu-button secondary">🏠 ${translations['main-menu'] || 'القائمة الرئيسية'}</button>
        </div>
        `;
    
    if (state.score > 0) {
        confetti({ particleCount: 150, spread: 180, origin: { y: 0.6 } });
    }

    loadInitialData();
}

// --- Event Listeners ---
elements.startGameButton.addEventListener("click", initializeGame);

elements.goToGameButton.addEventListener("click", () => {
    if (state.isGuest && !(isTelegram && tg.initData)) {
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
        showFloatingMessage(translations['login-required'] || "يجب image.png الدخول للوصول إلى قسم اختبار الحفظ.", false);
        showPage('login-page');
        return;
    }
    elements.result.style.display = 'none';
    document.querySelector('.tab-menu').style.display = 'flex';
    document.querySelector('#surah-tab').style.display = 'block';
    document.querySelector('#juz-tab').style.display = 'none';
    document.getElementById('start-game-button').style.display = 'block';
    document.getElementById('total-score-display').style.display = 'block';
            
    elements.tabButtons.forEach(btn => btn.classList.remove('active'));
    document.querySelector('.tab-button[data-tab="surah-tab"]').classList.add('active');
    
    state.currentGameType = 'surah';

    showPage('game-lobby-page');
});

elements.tabButtons.forEach(button => {
    button.addEventListener('click', () => {
        elements.tabButtons.forEach(btn => btn.classList.remove('active'));
        button.classList.add('active');
        const tabId = button.dataset.tab;
        
        elements.surahTab.style.display = 'none';
        elements.juzTab.style.display = 'none';
        
        if (tabId === 'surah-tab') {
            elements.surahTab.style.display = 'block';
            state.currentGameType = 'surah';
        } else if (tabId === 'juz-tab') {
            elements.juzTab.style.display = 'block';
            state.currentGameType = 'juz';
        }
    });
});

// Helper function to generate the HTML for Surah buttons based on type (tafsir or audio)
function generateSurahButtonsHTML(surahs, type) {
    if (!surahs || surahs.length === 0) {
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
        return `<p style="text-align:center; padding: 1rem;">${translations['no-surahs-found'] || 'لا توجد سور مطابقة للبحث.'}</p>`;
    }

    return surahs.map(surah => {
        if (type === 'audio') {
            return `<button class="surah-button" data-surah-id="${surah.surah_order}" data-surah-name="${surah.surah_name}">${surah.surah_name}</button>`;
        }
        // **هذا هو السطر الذي تم تعديله**
        // The default case now serves both Tafsir (needs data-surah) and Recitation (needs data-surah-name and data-surah-order)
        return `<button class="surah-button" data-surah="${surah.surah_name}" data-surah-name="${surah.surah_name}" data-surah-order="${surah.surah_order}">${surah.surah_name}</button>`;
    }).join('');
}
// Update the verse selection panel after selecting a surah
    function updateVerseSelectionPanel(surahName, surahOrder) {
        const selectedSurah = state.surahs.find(s => s.surah_order === surahOrder);
        if (!selectedSurah) return;

        state.recitation.selectedSurah = selectedSurah;
        state.recitation.totalVerses = selectedSurah.total_verses;
        
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
    elements.selectedSurahInfo.textContent = `${translations['choose-verses-from-surah'] || 'اختر الآيات من سورة'} ${surahName}:`;

        elements.startVerseInput.min = 1;
        elements.startVerseInput.max = state.recitation.totalVerses;
        elements.startVerseInput.value = 1;
        elements.endVerseInput.min = 1;
        elements.endVerseInput.max = state.recitation.totalVerses;
        elements.endVerseInput.value = state.recitation.totalVerses;
        elements.startVerseSlider.min = 1;
        elements.startVerseSlider.max = state.recitation.totalVerses;
        elements.startVerseSlider.value = 1;
        elements.endVerseSlider.min = 1;
        elements.endVerseSlider.max = state.recitation.totalVerses;
        elements.endVerseSlider.value = state.recitation.totalVerses;

        elements.recitationSurahListContainer.style.display = 'none';
        elements.recitationSurahSearchInput.style.display = 'none';
        elements.verseSelectionPanel.style.display = 'block';
    }

    async function renderRecitationTestPage() {       
        elements.recitationSurahListContainer.style.display = 'none';
        elements.recitationSurahSearchInput.style.display = 'none';
        elements.verseSelectionPanel.style.display = 'none';
        
        elements.recitationTestPanel.style.display = 'block';
        elements.recitationTestResults.style.display = 'none';

        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
        elements.recitationPage.querySelector('.page-header h2').textContent = `${translations['recitation'] || 'تسميع'} ${state.recitation.selectedSurah.surah_name}`;
        elements.recitationVersesDisplay.innerHTML = `<p style="text-align:center;">${translations['loading-verses'] || 'جاري جلب الآيات...'}</p>`;
        elements.recordBtn.innerHTML  = `<i class="fas fa-microphone"></i> ${translations['start-recording'] || 'ابدأ التسجيل'}`;
        elements.recordBtn.style.display = 'block';
        elements.playBackBtn.style.display = 'none';
        elements.recitationVersesDisplay.style.display = 'block';

        try {
            const verses = await apiRequest(`/recite/verses?surah_order=${state.recitation.selectedSurah.surah_order}&start_verse=${state.recitation.startVerse}&end_verse=${state.recitation.endVerse}`);
            state.recitation.versesToTest = verses;
            
            displayVerses(verses, true);
            elements.recordBtn.style.display = 'block';

        } catch (e) {
            elements.recitationVersesDisplay.innerHTML = `<p style="text-align:center; color:red;">${translations['failed-load-verses'] || 'فشل جلب الآيات. يرجى المحاولة لاحقًا.'}</p>`;
            elements.recordBtn.style.display = 'none';
            console.error("Failed to fetch verses for recitation:", e);
        }
    }
    
    function displayVerses(verses, show) {
        let versesHTML = verses.map(v => {
            // قمنا بتغيير هذا السطر ليضيف رقم الآية بعد كل آية
            return `<span class="verse">${v.verse_text}</span><span class="verse-number">${v.numberinsurah}</span>`;
        }).join(''); // تم تغيير الفاصل هنا أيضًا

        elements.recitationVersesDisplay.innerHTML = `<p class="recitation-text">${versesHTML}</p>`;
        elements.recitationVersesDisplay.style.opacity = show ? 1 : 0;
    }

    async function toggleRecording_() {
        const recordBtn = elements.recordBtn;
        
        if (state.recitationAudioRecorder && state.recitationAudioRecorder.state === 'recording') {
            const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
            const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
            recordBtn.textContent = translations['processing'] || 'جاري المعالجة...';
            recordBtn.disabled = true;
            state.recitationAudioRecorder.stop();
            return;
        }

        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });

            state.recitationAudioRecorder = new MediaRecorder(stream, { mimeType: 'audio/webm;codecs=opus' });
            state.recitationAudioChunks = [];
            
            state.recitationAudioRecorder.ondataavailable = (e) => {
                state.recitationAudioChunks.push(e.data);
            };
            
            state.recitationAudioRecorder.onstop = async () => {
                const audioBlob = new Blob(state.recitationAudioChunks, { type: 'audio/webm;codecs=opus' });
                state.recordedAudioBlob = audioBlob; // NEW: Save the audio blob for playback
                elements.playBackBtn.style.display = 'block'; // NEW: Show the playback button

                //elements.recordBtn.innerHTML = '<i class="fas fa-microphone"></i> ابدأ التسجيل'; // أيقونة ميكروفون
                elements.recordBtn.style.backgroundColor = ''; // إزالة اللون الأحمر للعودة للون الافتراضي
            
                const reader = new FileReader();
                reader.readAsDataURL(audioBlob);
                reader.onloadend = () => {
                    const base64data = reader.result.split(',')[1];
                    sendRecitationToAPI(base64data);
                };
            };

            state.recitationAudioRecorder.start();
            
            displayVerses(state.recitation.versesToTest, false);

            recordBtn.innerHTML = '<i class="fas fa-stop"></i> إيقاف التسجيل'; // أيقونة إيقاف
            recordBtn.style.backgroundColor = 'red'; // لون أحمر للتوقف
            
            recordBtn.textContent = 'أوقف التسجيل';

        } catch (e) {
            const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
            const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
            showFloatingMessage(translations['microphone-access-failed'] || "فشل الوصول للميكروفون. يرجى التأكد من السماح للتطبيق بالوصول إليه.", false);
            console.error("Failed to get audio stream:", e);
        }
    }
    async function toggleRecording() {
        const recordBtn = elements.recordBtn;

        // --- Stop Recording Logic ---
        if (state.recitationAudioRecorder && state.recitationAudioRecorder.state === 'recording') {
            const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
            const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
            recordBtn.textContent = translations['processing'] || 'جاري المعالجة...';
            recordBtn.disabled = true;
            recordBtn.style.backgroundColor = ''; // Reset color
            state.recitationAudioRecorder.stop();

            if (state.mediaStream) {
                state.mediaStream.getTracks().forEach(track => track.stop());
                state.mediaStream = null;
            }
            return;
        }

        // --- Start Recording Logic ---
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            state.mediaStream = stream;
            state.recitationAudioRecorder = new MediaRecorder(stream, { mimeType: 'audio/webm;codecs=opus' });
            state.recitationAudioChunks = [];

            state.recitationAudioRecorder.ondataavailable = (e) => {
                state.recitationAudioChunks.push(e.data);
            };

            state.recitationAudioRecorder.onstop = async () => {
                const audioBlob = new Blob(state.recitationAudioChunks, { type: 'audio/webm;codecs=opus' });
                state.recordedAudioBlob = audioBlob;
                elements.playBackBtn.style.display = 'block';
                
                // New flow: Upload to GCS and then process
                await processAudioUploadAndTest(audioBlob);
            };

            state.recitationAudioRecorder.start();
            displayVerses(state.recitation.versesToTest, false);

            recordBtn.innerHTML = '<i class="fas fa-stop"></i> إيقاف التسجيل';
            recordBtn.style.backgroundColor = '#dc3545';

        } catch (e) {
            const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
            const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
            showFloatingMessage(translations['microphone-access-failed'] || "فشل الوصول للميكروفون. يرجى التأكد من السماح للتطبيق بالوصول إليه.", false);
            console.error("Failed to get audio stream:", e);
            elements.recordBtn.disabled = false;
            elements.recordBtn.innerHTML = `<i class="fas fa-microphone"></i> ${translations['start-recording'] || 'ابدأ التسجيل'}`;
        }
    }

    // NEW: Orchestrator function for the GCS upload and test process
    async function processAudioUploadAndTest(audioBlob) {
        const recordBtn = elements.recordBtn;
        try {
            // Step 1: Get the secure upload URL from our server
            const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
            const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
            showFloatingMessage(translations['uploading-secure'] || "...جاري تهيئة الرفع الآمن", true);
            const { uploadUrl, gcsUri } = await apiRequest('/recite/generate-upload-url', {
                method: 'POST',
                body: JSON.stringify({ contentType: audioBlob.type })
            });

            // Step 2: Upload the audio file directly to Google Cloud Storage
            showFloatingMessage(translations['uploading-recording'] || "...جاري رفع التسجيل", true);
            const uploadResponse = await fetch(uploadUrl, {
                method: 'PUT',
                body: audioBlob,
                headers: {
                    'Content-Type': audioBlob.type
                }
            });

            if (!uploadResponse.ok) {
                throw new Error('فشل رفع الملف إلى Google Cloud Storage.');
            }

            // Step 3: Send the GCS URI to our server to start the transcription
            showFloatingMessage(translations['analyzing-recitation'] || "...جاري تحليل التسميع", true);
            await sendRecitationToAPIBucket(gcsUri);

        } catch (e) {
            showFloatingMessage(`حدث خطأ: ${e.message}`, false);
            console.error("Recitation processing error:", e);
            recordBtn.disabled = false;
            recordBtn.innerHTML = '<i class="fas fa-microphone"></i> أعد الاختبار';
        }
    }
    // NEW: Function to handle audio playback
   // NEW: Function to handle audio playback with state management
    function playRecordedAudio() {
        if (state.recordedAudioBlob) {
            const playbackButton = elements.playBackBtn;

            // 1. Disable the button and change its text to show it's playing
            playbackButton.disabled = true;
            playbackButton.innerHTML = '🔊 ...جاري التشغيل';

            const audioUrl = URL.createObjectURL(state.recordedAudioBlob);
            const audio = new Audio(audioUrl);

            // 2. Define a function to reset the button to its original state
            const resetButtonState = () => {
                playbackButton.disabled = false;
                const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
                const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
                playbackButton.innerHTML = `${translations['listen-recording'] || 'استمع للتسجيل'} 🎧`;
            };

            // 3. Listen for when the audio finishes playing
            audio.onended = () => {
                console.log("Playback finished.");
                resetButtonState();
            };
            
            // (Optional but good practice) Handle errors during playback
            audio.onerror = () => {
                console.error("Error playing recorded audio.");
                const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
                const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
                showFloatingMessage(translations['audio-playback-error'] || "حدث خطأ أثناء تشغيل الصوت.", false);
                resetButtonState();
            };

            // 4. Play the audio
            audio.play();

        } else {
            showFloatingMessage(translations['no-recording-to-play'] || "لا يوجد تسجيل للاستماع إليه.", false);
        }
    }

    // RENAMED AND UPDATED to use GCS URI
    async function sendRecitationToAPIBucket(gcsUri) {
        try {
            const payload = {
                gcsUri: gcsUri,
                surahOrder: state.recitation.selectedSurah.surah_order,
                startVerse: state.recitation.startVerse,
                endVerse: state.recitation.endVerse,
            };
            
            const result = await apiRequest('/recite/test_bucket', {
                method: 'POST',
                body: JSON.stringify(payload)
            });

            renderRecitationResults(result);

        } catch (e) {
            showFloatingMessage(translations['recitation-processing-failed'] || "فشل معالجة التسميع. يرجى المحاولة مرة أخرى.", false);
            console.error("Recitation API error:", e);
            // Re-enable the button on failure
            const recordBtn = elements.recordBtn;
            recordBtn.disabled = false;
            recordBtn.innerHTML = '<i class="fas fa-microphone"></i> أعد الاختبار';
        }
    }
    async function sendRecitationToAPI(base64data) {
        try {
            const payload = {
                audio: base64data,
                surahOrder: state.recitation.selectedSurah.surah_order,
                startVerse: state.recitation.startVerse,
                endVerse: state.recitation.endVerse,
            };
            
            const result = await apiRequest('/recite/test', {
                method: 'POST',
                body: JSON.stringify(payload)
            });

            renderRecitationResults(result);

        } catch (e) {
            showFloatingMessage(translations['recitation-processing-failed'] || "فشل معالجة التسميع. يرجى المحاولة مرة أخرى.", false);
            console.error("Recitation API error:", e);
        }
    }

    function renderRecitationResults(result) {
        elements.recitationVersesDisplay.style.display = 'none';
        elements.recitationTestResults.style.display = 'block';
        elements.recitationAccuracy.textContent = `${result.overall_accuracy}%`;
        elements.recitationComparisonResults.innerHTML = '';

        result.results.forEach(verseResult => {
            const verseDiv = document.createElement('div');
            verseDiv.className = 'verse-result';
            verseDiv.innerHTML = `<p>${verseResult.highlighted_text}</p>`; 
            elements.recitationComparisonResults.appendChild(verseDiv);
        });

        elements.recordBtn.textContent = 'أعد الاختبار';
        elements.recordBtn.disabled = false;
    }

    function normalizeArabicText(text) {
        if (!text) return '';
        text = text.replace(/[\u064B-\u0652]/g, "");
        text = text.replace(/\u0640/g, "");
        text = text.replace(/[أإآٱ]/g, "ا");
        text = text.replace(/ة/g, "ه");
        text = text.replace(/ى/g, "ي");
        return text;
    }

// Renders the Surah selection view with a search bar for both Tafsir and Audio sections
function renderSurahSelection(type = 'tafsir') {
    const container = (type === 'audio') ? elements.audioPage : elements.tafsirPage;
    const backButtonId = (type === 'audio') ? 'back-to-main-menu-from-audio' : 'back-to-main-menu-from-tafsir';
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};

    const initialButtonsHTML = generateSurahButtonsHTML(state.surahs, type);

    container.innerHTML = `
        <div class="page-header">
            <h2 data-translate="choose-surah">${translations['choose-surah'] || 'اختر السورة'}</h2>
        </div>
        <div class="search-surah-container">
            <input type="text" id="surah-search-input" class="surah-search-input-field" placeholder="${translations['search-surah-placeholder'] || 'ابحث عن سورة...'}" autocomplete="off" />
        </div>
        <div class="surah-list" id="surah-list-container">${initialButtonsHTML}</div>
        <button class="back-button" id="${backButtonId}" aria-label="${translations['back-to-main-menu'] || 'العودة إلى القائمة الرئيسية'}">➡️</button>
    `;

    const searchInput = container.querySelector('#surah-search-input');
    const surahListContainer = container.querySelector('#surah-list-container');

    searchInput.addEventListener('input', (e) => {
        const searchTerm = e.target.value.trim();
        const normalizedSearchTerm = normalizeArabicText(searchTerm);
        const filteredSurahs = state.surahs.filter(surah => {
            const normalizedSurahName = normalizeArabicText(surah.surah_name);
            return normalizedSurahName.includes(normalizedSearchTerm);
        });
        surahListContainer.innerHTML = generateSurahButtonsHTML(filteredSurahs, type);
    });
}

function renderTafsirSelection() {
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
    
    let buttonsHTML = Object.keys(TAFSIR_OPTIONS).map(name => {
        const translatedName = translateTafsirBookName(name, currentLanguage);
        return `<button class="tafsir-button" data-tafsir-col="${TAFSIR_OPTIONS[name]}" data-tafsir-name="${name}">${translatedName}</button>`;
    }).join('');

    elements.tafsirPage.innerHTML = `
        <div class="page-header">
            <h2>${state.selectedSurah}</h2>
        </div>
        <p style="text-align:center; font-weight:bold; margin-bottom:1rem;" data-translate="please-choose-tafsir">${translations['please-choose-tafsir'] || 'الرجاء اختيار التفسير:'}</p>
        <div class="tafsir-options">${buttonsHTML}</div>
        <button class="back-button" id="back-to-surah-list" aria-label="${translations['back-to-surah-list'] || 'العودة إلى قائمة السور'}">➡️</button>
    `;
}

function renderAudioSelection() {
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
    
    let buttonsHTML = Object.keys(AUDIO_OPTIONS).map(name => {
        const translatedName = translateReciterName(name, currentLanguage);
        return `<button class="audio-button" data-reciter-id="${AUDIO_OPTIONS[name]}" data-reciter-name="${name}">${translatedName}</button>`;
    }).join('');

    elements.audioPage.innerHTML = `
        <div class="page-header">
            <h2>${state.selectedSurah}</h2>
        </div>
        <p style="text-align:center; font-weight:bold; margin-bottom:1rem;" data-translate="please-choose-reciter">${translations['please-choose-reciter'] || 'الرجاء اختيار القارئ:'}</p>
        <div class="tafsir-options">${buttonsHTML}</div>
        <button class="back-button" id="back-to-surah-list" aria-label="${translations['back-to-surah-list'] || 'العودة إلى قائمة السور'}">➡️</button>
    `;
}

function renderVerseView() {
    let versesHTML = state.verses.map(v => {
        const isExpanded = state.verseStates[v.id] || false;
        const sajdaSymbol = v.sajda ? ' <span class="sajda-symbol">۩</span>' : '';
        const expandedClass = isExpanded ? 'expanded' : '';
        const arrow = isExpanded ? '🔽' : '▶️';
        const verseKey = `${v.SurahOrder}-${v.numberInSurah}`;

        let playButtonHTML = '';
        if (state.selectedTafsir === '/data/muyassar_audio') {
            playButtonHTML = `
                <button class="play-tafsir-audio-btn" data-surah-order="${v.SurahOrder}" data-ayah-number="${v.numberInSurah}" aria-label="${translations['play-tafsir-audio'] || 'تشغيل صوت التفسير'}">
                    ▶️
                </button>
            `;
        }

        let verseHTML = `
            <div class="verse-container" data-verse-key="${verseKey}">
                <button class="verse-button ${expandedClass}" data-verse-id="${v.id}">
                    <div class="verse-button-content">
                        ${playButtonHTML}
                        <span>${arrow} ${v.verse_text}${sajdaSymbol}</span>
                    </div>
                </button>
        `;
        if (isExpanded) {
            verseHTML += `
                <div class="tafsir-text-panel">${v.tafsir_text}</div>
                <div class="verse-info-panel">
                    الجزء: ${v.juz} | الصفحة: ${v.page} | رقم الآية: ${v.numberInSurah}
                </div>
            `;
        }
        verseHTML += `</div>`;
        return verseHTML;
    }).join('');

    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const translatedTafsirName = translateTafsirBookName(state.selectedTafsirName, currentLanguage);
    
    elements.tafsirPage.innerHTML = `
        <div class="page-header">
            <h2>${state.selectedSurah} - ${translatedTafsirName}</h2>
        </div>
        <div class="verse-list">${versesHTML}</div>
        <button class="back-button" id="back-to-tafsir-list" aria-label="${translations['back-to-tafsir-list'] || 'العودة إلى قائمة التفاسير'}">➡️</button>
    `;
}

let currentPlayingVerseKey = null;

function playTafsirAudio(surahOrder, ayahNumber) {
    elements.fullAudioPlayer.pause();
    
    const audioSrc = generateAyahURL(surahOrder, ayahNumber);
    const audioPlayer = elements.audioPlayer;

    if (audioPlayer.src.endsWith(audioSrc) && !audioPlayer.paused) {
        audioPlayer.pause();
        return;
    }
    
    audioPlayer.src = audioSrc;
    audioPlayer.loop = false; 
    currentPlayingVerseKey = `${surahOrder}-${ayahNumber}`;

    audioPlayer.play().catch(e => {
        console.error("Audio play failed for tafsir:", e);
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
        showFloatingMessage(translations['audio-playback-failed'] || "فشل تشغيل الصوت.", false);
    });
}

elements.audioPlayer.addEventListener('play', () => {
    if (elements.tafsirPage.style.display !== 'none' && state.selectedTafsir === '/data/muyassar_audio') {
        document.querySelectorAll('.verse-container .verse-button').forEach(btn => btn.classList.remove('playing'));
        document.querySelectorAll('.play-tafsir-audio-btn').forEach(btn => btn.textContent = '▶️');
        
        if (currentPlayingVerseKey) {
            const currentVerseButton = document.querySelector(`.verse-container[data-verse-key="${currentPlayingVerseKey}"] .verse-button`);
            const playIcon = document.querySelector(`.verse-container[data-verse-key="${currentPlayingVerseKey}"] .play-tafsir-audio-btn`);
            
            if (currentVerseButton) {
                currentVerseButton.classList.add('playing');
            }
            if (playIcon) {
                playIcon.textContent = '⏸️';
            }
        }
    }
});

elements.audioPlayer.addEventListener('pause', () => {
    if (elements.tafsirPage.style.display !== 'none' && state.selectedTafsir === '/data/muyassar_audio') {
        if (currentPlayingVerseKey) {
            const playIcon = document.querySelector(`.verse-container[data-verse-key="${currentPlayingVerseKey}"] .play-tafsir-audio-btn`);
            if(playIcon) playIcon.textContent = '▶️';
        }
    }
});


elements.audioPlayer.addEventListener('ended', () => {
if (elements.tafsirPage.style.display === 'none' || state.selectedTafsir !== '/data/muyassar_audio') {
    return;
}

const currentVerseEl = document.querySelector(`.verse-container[data-verse-key="${currentPlayingVerseKey}"]`);
if (!currentVerseEl) return;

currentVerseEl.querySelector('.verse-button')?.classList.remove('playing');
const playIcon = currentVerseEl.querySelector('.play-tafsir-audio-btn');
if(playIcon) playIcon.textContent = '▶️';

const nextVerseEl = currentVerseEl.nextElementSibling;
if (nextVerseEl && nextVerseEl.classList.contains('verse-container')) {
    const nextPlayBtn = nextVerseEl.querySelector('.play-tafsir-audio-btn');
    if (nextPlayBtn) {
        nextPlayBtn.click();
    }
} else {
    currentPlayingVerseKey = null;
}
});


function generateAyahURL(surahNumber, ayahNumber) {
    const formattedSurah = surahNumber.toString().padStart(3, '0');
    const formattedAyah = ayahNumber.toString().padStart(3, '0');
    return `${state.selectedTafsir}/${formattedSurah}${formattedAyah}.mp3`;
}

function renderVerseForAudioView() {
    let versesHTML = state.verses.map(v => {
        const isExpanded = state.verseStates[v.id] || false;
        const sajdaSymbol = v.sajda ? ' <span class="sajda-symbol">۩</span>' : '';
        const expandedClass = isExpanded ? 'expanded' : '';
        const arrow = isExpanded ? '🔽' : '▶️';
        
        let audioSrc = generateAyahURL(v.SurahOrder, v.numberInSurah);

        let verseHTML = `
            <div class="verse-container">
                <button class="verse-button ${expandedClass}" data-src="${audioSrc}"  data-verse-id="${v.id}">${arrow} ${v.verse_text}${sajdaSymbol}</button>
        `;
        let translaionText = '';
        if (state.selectedTafsir === '/data/ayahs/arabic-french') {
            translaionText = v.verse_text_fr;
        } else if (state.selectedTafsir === '/data/ayahs/arabic-english') {
            translaionText = v.verse_text_en;
        }
        if (isExpanded) {
            verseHTML += `
                <div class="tafsir-text-panel">${translaionText}</div>
                <div class="verse-info-panel">
                    الجزء: ${v.juz} | الصفحة: ${v.page} | رقم الآية: ${v.numberInSurah}
                </div>
            `;
        }
        verseHTML += `</div>`;
        return verseHTML;
    }).join('');

    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const translatedTafsirName = translateReciterName(state.selectedTafsirName, currentLanguage);
    
    elements.audioPage.innerHTML = `
        <div class="page-header">
            <h2>${state.selectedSurah} - ${translatedTafsirName}</h2>
        </div>
        <div class="verse-list">${versesHTML}</div>
        <button class="back-button" id="back-to-tafsir-list" aria-label="${translations['back-to-reciter-list'] || 'العودة إلى قائمة القراء'}">➡️</button>
    `;
}

let last_audioSrc = null;

document.addEventListener("click", function (e) {
    if (e.target.classList.contains("verse-button")) {
        elements.fullAudioPlayer.pause();
        const audioSrc = e.target.getAttribute('data-src');
        if (audioSrc) {
          if (audioSrc === last_audioSrc && !elements.audioPlayer.paused) {
              elements.audioPlayer.pause();
          } else {
            elements.audioPlayer.src = audioSrc;
            elements.audioPlayer.loop = true;
            last_audioSrc = audioSrc;
            elements.audioPlayer.play();
        }
    }
} else if (!e.target.closest('#full-audio-player-container')) {
    elements.audioPlayer.loop = false;
    elements.audioPlayer.pause();
}});

elements.goToTafsirButton.addEventListener("click", async () => {
    showPage('tafsir-page');
    try {
        elements.tafsirPage.innerHTML = `<p style="text-align:center;">جاري تحميل السور...</p>`;
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const surahs = await loadSurahData(currentLanguage);
        state.surahs = surahs;
        renderSurahSelection('tafsir');
    } catch (e) {
        elements.tafsirPage.innerHTML = `<p style="text-align:center; color:red;">للأسف فشل تحميل السور.</p>`;
        console.error("حدث خطأ أثناء تحميل السور:", e);
    }
});

elements.tafsirPage.addEventListener('click', async (e) => {
    const playBtn = e.target.closest('.play-tafsir-audio-btn');
    if (playBtn) {
        e.stopPropagation(); 
        playTafsirAudio(playBtn.dataset.surahOrder, playBtn.dataset.ayahNumber);
        return; 
    }

    const target = e.target.closest('button');
    if (!target) return;

    if (target.id === 'back-to-main-menu-from-tafsir') {
        showPage('main-menu-page');
    } else if (target.id === 'back-to-surah-list') {
        renderSurahSelection('tafsir');
    } else if (target.id === 'back-to-tafsir-list') {
        renderTafsirSelection();
    } else if (target.matches('.surah-button')) {
        state.selectedSurah = target.dataset.surah;
        renderTafsirSelection();
    } else if (target.matches('.tafsir-button')) {
        state.selectedTafsir = target.dataset.tafsirCol;
        state.selectedTafsirName = target.dataset.tafsirName;
        state.verseStates = {};
        elements.tafsirPage.innerHTML = `<p style="text-align:center;">جاري تحميل الآيات...</p>`;
        try {
            const arabicSurahName = getArabicSurahName(state.selectedSurah);
            const tafsirParam = state.selectedTafsir === '/data/muyassar_audio' ? 'muyassar' : state.selectedTafsir;
            const { verses } = await apiRequest(`/verses?surah=${arabicSurahName}&tafsir=${tafsirParam}`);
            state.verses = verses.map(v => ({...v, tafsir_text: v.tafsir_text || (translations['tafsir-not-available'] || "التفسير غير متوفر لهذه الآية")}));
            renderVerseView();
        } catch (err) {
            elements.tafsirPage.innerHTML = `<p style="text-align:center; color:red;">فشل تحميل الآيات.</p>`;
        }
    } else if (target.matches('.verse-button')) {
        const verseId = target.dataset.verseId;
        state.verseStates[verseId] = !state.verseStates[verseId];
        renderVerseView();
    }
});


elements.goToAudioButton.addEventListener("click", async () => {
    showPage('audio-page');
    try {
        elements.audioPage.innerHTML = `<p style="text-align:center;">جاري تحميل السور...</p>`;
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const surahs = await loadSurahData(currentLanguage);
        state.surahs = surahs;
        renderSurahSelection('audio');
    } catch (e) {
        elements.audioPage.innerHTML = `<p style="text-align:center; color:red;">للأسف فشل تحميل السور.</p>`;
        console.error("حدث خطأ أثناء تحميل السور:", e);
    }
});

elements.audioPage.addEventListener('click', async (e) => {
    const target = e.target.closest('button');
    if (!target) return;

    if (target.id === 'back-to-main-menu-from-audio') showPage('main-menu-page');
    else if (target.id === 'back-to-surah-list') renderSurahSelection('audio');
    else if (target.id === 'back-to-tafsir-list') renderAudioSelection();
    else if (target.matches('.surah-button')) {
        state.selectedSurah = target.dataset.surahName;
        renderAudioSelection();
    } else if (target.matches('.audio-button')) {
        state.selectedTafsir = target.dataset.reciterId;
        state.selectedTafsirName = target.dataset.reciterName;
        state.verseStates = {};
        elements.audioPage.innerHTML = `<p style="text-align:center;">جاري تحميل الآيات...</p>`;
        try {
            const arabicSurahName = getArabicSurahName(state.selectedSurah);
            const { verses } = await apiRequest(`/verses?surah=${arabicSurahName}&tafsir=${state.selectedTafsir}`);
            state.verses = verses;
            renderVerseForAudioView();
        } catch (err) {
             elements.audioPage.innerHTML = `<p style="text-align:center; color:red;">فشل تحميل الآيات.</p>`;
        }
    } else if (target.matches('.verse-button')) {
        const verseId = target.dataset.verseId;
        state.verseStates[verseId] = !state.verseStates[verseId];
        renderVerseForAudioView();
    }
});

// --- Full Surah Audio Logic ---
function generateFullAudioSurahButtonsHTML(surahs) {
    if (!surahs || surahs.length === 0) {
        return '<p style="text-align:center; padding: 1rem;">لا توجد سور مطابقة للبحث.</p>';
    }
    return surahs.map(surah =>
        `<button class="surah-button" data-surah-order="${surah.surah_order}" data-surah-name="${surah.surah_name}">${surah.surah_name}</button>`
    ).join('');
}

function renderFullAudioSurahSelection() {
    const initialButtonsHTML = generateFullAudioSurahButtonsHTML(state.surahs);

    elements.fullAudioPage.innerHTML = `
        <div class="page-header">
            <h2 data-translate="choose-surah">${translations['choose-surah'] || 'اختر السورة'}</h2>
        </div>
        <div class="search-surah-container">
            <input type="text" id="full-audio-surah-search-input" class="surah-search-input-field" placeholder="${translations['search-surah-placeholder'] || 'ابحث عن سورة...'}" autocomplete="off" />
        </div>
        <div class="surah-list" id="full-audio-surah-list-container">${initialButtonsHTML}</div>
        <button class="back-button" id="back-to-main-menu-from-full-audio" aria-label="${translations['back-to-main-menu'] || 'العودة إلى القائمة الرئيسية'}">➡️</button>
    `;

    const searchInput = elements.fullAudioPage.querySelector('#full-audio-surah-search-input');
    const surahListContainer = elements.fullAudioPage.querySelector('#full-audio-surah-list-container');

    searchInput.addEventListener('input', (e) => {
        const searchTerm = e.target.value.trim();
        const normalizedSearchTerm = normalizeArabicText(searchTerm);
        const filteredSurahs = state.surahs.filter(surah => {
            const normalizedSurahName = normalizeArabicText(surah.surah_name);
            return normalizedSurahName.includes(normalizedSearchTerm);
        });
        surahListContainer.innerHTML = generateFullAudioSurahButtonsHTML(filteredSurahs);
    });
}

function renderReciterSelection() {
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    let buttonsHTML = Object.keys(FULL_AUDIO_OPTIONS).map(name => {
        const translatedName = translateReciterName(name, currentLanguage);
        return `<button class="audio-button" data-reciter-key="${FULL_AUDIO_OPTIONS[name]}" data-reciter-name="${name}">${translatedName}</button>`;
    }).join('');
    elements.fullAudioPage.innerHTML = `
        <div class="page-header">
            <h2>${state.selectedSurah}</h2>
        </div>
        <p style="text-align:center; font-weight:bold; margin-bottom:1rem;" data-translate="please-choose-reciter">${translations['please-choose-reciter'] || 'الرجاء اختيار القارئ:'}</p>
        <div class="tafsir-options">${buttonsHTML}</div>
        <button class="back-button" id="back-to-full-audio-surah-list" aria-label="${translations['back-to-surah-list'] || 'العودة إلى قائمة السور'}">➡️</button>
    `;
}

function generateFullSurahURL(surahOrder, reciterKey) {
    const formattedSurah = surahOrder.toString().padStart(3, '0');
    return `${reciterKey}/${formattedSurah}.mp3`;
}

function setupFullAudioPlayer(audioSrc) {
    const player = elements.fullAudioPlayer;
    player.src = audioSrc;

    const playPauseBtn = document.getElementById('play-pause-btn');
    const forwardBtn = document.getElementById('forward-btn');
    const rewindBtn = document.getElementById('rewind-btn');
    const repeatBtn = document.getElementById('repeat-btn');
    const speedBtns = document.querySelectorAll('.speed-btn');
    const timelineContainer = document.getElementById('timeline-container');
    const timeline = document.getElementById('timeline');
    const currentTimeEl = document.getElementById('current-time');
    const totalDurationEl = document.getElementById('total-duration');
    const volumeSlider = document.getElementById('volume-slider');

    const formatTime = (time) => {
        if (isNaN(time)) return "00:00:00";
        const hours = Math.floor(time / 3600);
        const minutes = Math.floor((time % 3600) / 60);
        const seconds = Math.floor(time % 60);
        return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
    }

    const savedVolume = localStorage.getItem('quranPlayerVolume');
    if (savedVolume !== null) {
        player.volume = savedVolume;
        volumeSlider.value = savedVolume * 100;
    } else {
        player.volume = 1;
        volumeSlider.value = 100;
    }
    volumeSlider.addEventListener('input', (e) => {
        const volumeValue = e.target.value / 100;
        player.volume = volumeValue;
        localStorage.setItem('quranPlayerVolume', volumeValue);
    });

    playPauseBtn.addEventListener('click', () => player.paused ? player.play() : player.pause());
    player.addEventListener('play', () => playPauseBtn.classList.add('playing'));
    player.addEventListener('pause', () => playPauseBtn.classList.remove('playing'));

    forwardBtn.addEventListener('click', () => player.currentTime += 10);
    rewindBtn.addEventListener('click', () => player.currentTime -= 10);

    repeatBtn.addEventListener('click', () => {
        player.loop = !player.loop;
        repeatBtn.classList.toggle('active', player.loop);
    });

    speedBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            speedBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            player.playbackRate = parseFloat(btn.dataset.speed);
        });
    });

    player.addEventListener('loadedmetadata', () => totalDurationEl.textContent = formatTime(player.duration));
    player.addEventListener('timeupdate', () => {
        currentTimeEl.textContent = formatTime(player.currentTime);
        if(player.duration) {
           timeline.style.width = `${(player.currentTime / player.duration) * 100}%`;
        }
    });

    timelineContainer.addEventListener('click', (e) => {
        const timelineWidth = timelineContainer.clientWidth;
        if (player.duration) {
            player.currentTime = (e.offsetX / timelineWidth) * player.duration;
        }
    });

    player.play().catch(e => console.error("Audio play failed:", e));
}

elements.goToFullAudioButton.addEventListener("click", async () => {
    showPage('full-audio-page');
    try {
        elements.fullAudioPage.innerHTML = `<p style="text-align:center;">جاري تحميل السور...</p>`;
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const surahs = await loadSurahData(currentLanguage);
        state.surahs = surahs;
        renderFullAudioSurahSelection();
    } catch (e) {
        elements.fullAudioPage.innerHTML = `<p style="text-align:center; color:red;">للأسف فشل تحميل السور.</p>`;
        console.error("حدث خطأ أثناء تحميل السور:", e);
    }
});

elements.fullAudioPage.addEventListener('click', async (e) => {
    const target = e.target.closest('button');
    if (!target) return;

    if (target.id === 'back-to-main-menu-from-full-audio') showPage('main-menu-page');
    else if (target.id === 'back-to-full-audio-surah-list') renderFullAudioSurahSelection();
    else if (target.id === 'back-to-reciter-list') {
        renderReciterSelection();
    }
    else if (target.matches('.surah-button')) {
        state.selectedSurah = target.dataset.surahName;
        state.selectedSurahOrder = target.dataset.surahOrder;
        renderReciterSelection();
    } else if (target.matches('.audio-button')) {
        state.selectedReciter = target.dataset.reciterKey;
        const audioSrc = generateFullSurahURL(state.selectedSurahOrder, state.selectedReciter);
        renderFullAudioPlayer(audioSrc);
    }
});
  function renderFullAudioPlayer(audioSrc) {
        elements.fullAudioPage.innerHTML = `
            <div class="page-header">
                <h2>${state.selectedSurah.split('-').slice(1).join('-')}</h2>
            </div>
            <div id="full-audio-player-container">
                <div class="player-controls">
                    <button id="rewind-btn" title="${translations['rewind-10s'] || 'تأخير 10 ثواني'}">⏭️</button>
                    <button id="play-pause-btn" title="${translations['play-pause'] || 'تشغيل/إيقاف'}">
                        <span class="play-icon">▶️</span>
                        <span class="pause-icon">⏸️</span>
                    </button>
                    <button id="forward-btn" title="${translations['forward-10s'] || 'تقديم 10 ثواني'}">⏮️</button>
                </div>
                <div id="timeline-container"><div id="timeline"></div></div>
                <div class="time-info">
                    <span id="current-time">00:00:00</span> / <span id="total-duration">00:00:00</span>
                </div>
                <div class="extra-controls">
                    <div class="speed-controls">
                        <span>السرعة:</span>
                        <button data-speed="1" class="speed-btn active">1x</button>
                        <button data-speed="1.25" class="speed-btn">1.25x</button>
                        <button data-speed="1.5" class="speed-btn">1.5x</button>
                        <button data-speed="2" class="speed-btn">2x</button>
                    </div>
                    <div class="volume-controls">
                        <span>🔊</span>
                        <input type="range" id="volume-slider" min="0" max="100" value="100">
                    </div>
                    <button id="repeat-btn" title="${translations['repeat'] || 'تكرار'}">🔁</button>
                </div>
            </div>
            <button class="back-button" id="back-to-reciter-list" aria-label="${translations['back-to-reciter-list'] || 'العودة إلى قائمة القراء'}">➡️</button>
        `;
        setupFullAudioPlayer(audioSrc);
    }
// --- START: Tasbeeh Logic (Modified) ---
const DEFAULT_TASBEEH_PHRASES = [
    "سبحان الله",
    "الحمد لله",
    "لا إله إلا الله",
    "الله أكبر",
    "أستغفر الله",
    "لا حول ولا قوة إلا بالله",
    "سبحان الله وبحمده، سبحان الله العظيم",
    "اللهم صلي على سيدنا محمد وعلى آل سيدنا محمد",
    "رضيت بالله ربا، وبالإسلام دينا، وبمحمد ﷺ نباً ورسولا",
    "حسبي الله لا إله إلا هو عليه توكلت وهو رب العرش العظيم",
    "يا حي يا قيوم برحمتك أستغيث",
    "اللهم اغفر لي ولوالدي وللمؤمنين والمؤمنات",
    "اللهم إنك عفو تحب العفو فاعفُ عني",
    "اللهم لك الحمد كما ينبغي لجلال وجهك وعظيم سلطانك",
    "اللهم ثبت قلبي على دينك",
    "اللهم اجعلني من التوابين واجعلني من المتطهرين",
    "اللهم إني أسألك الجنة وأعوذ بك من النار",
    "اللهم اشرح لي صدري ويسر لي أمري"
];

function getTasbeehPhrases() {
    const savedPhrases = JSON.parse(localStorage.getItem('userTasbeehPhrases'));
    return savedPhrases || DEFAULT_TASBEEH_PHRASES;
}

function saveTasbeehPhrases(phrases) {
    localStorage.setItem('userTasbeehPhrases', JSON.stringify(phrases));
}


function getTasbeehTotalCounts() {
    return JSON.parse(localStorage.getItem('tasbeehTotalCounts')) || {};
}

function saveTasbeehTotalCounts(counts) {
    localStorage.setItem('tasbeehTotalCounts', JSON.stringify(counts));
}

function renderTasbeehPage() {
    const tasbeehPhrases = getTasbeehPhrases();
    const totalCounts = getTasbeehTotalCounts();
    let tasbeehHTML = tasbeehPhrases.map((phrase, index) => {
        const sessionCount = state.tasbeehSessionCounts[index] || 0;
        const totalCount = totalCounts[index] || 0;
        return `
            <div class="tasbeeh-item" data-index="${index}">
                <button class="reset-session" title="${getTranslation('reset-session-counter')}" aria-label="${getTranslation('reset-session-counter')}">🔄</button>
                <div class="tasbeeh-text">${phrase}</div>
                <div class="tasbeeh-counters">
                    <div>
                        ${getTranslation('current-session')}
                        <span class="counter-value session-counter">${sessionCount}</span>
                    </div>
                    <div>
                        ${getTranslation('total')}
                        <span class="counter-value total-counter">${totalCount}</span>
                    </div>
                </div>
            </div>
        `;
    }).join('');

    const tasbeehContainer = document.getElementById('tasbeeh-container');
    tasbeehContainer.innerHTML = tasbeehHTML;
    tasbeehContainer.style.display = 'flex';
    document.getElementById('edit-tasbeeh-panel').style.display = 'none';
}

let draggingItem = null;

function renderEditTasbeehPanel() {
    const currentPhrases = getTasbeehPhrases();
    const listElement = document.getElementById('edit-tasbeeh-list');
    listElement.innerHTML = ''; 

    currentPhrases.forEach((phrase, index) => {
        const li = document.createElement('li');
        li.setAttribute('draggable', 'true');
        li.setAttribute('data-index', index);
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
        li.innerHTML = `
            <span>${phrase}</span>
            <button class="delete-tasbeeh-btn" data-phrase="${phrase}">${translations['delete'] || 'حذف'}</button>
        `;
        listElement.appendChild(li);
    });

    // Add drag and drop event listeners to new list items
    const listItems = listElement.querySelectorAll('li');
    listItems.forEach(item => {
        item.addEventListener('dragstart', handleDragStart);
        item.addEventListener('dragover', handleDragOver);
        item.addEventListener('dragleave', handleDragLeave);
        item.addEventListener('drop', handleDrop);
        item.addEventListener('dragend', handleDragEnd);
    });

    document.getElementById('tasbeeh-container').style.display = 'none';
    document.getElementById('edit-tasbeeh-panel').style.display = 'block';
    document.getElementById('edit-tasbeeh-list-btn').style.display = 'none';
    document.getElementById('reset-all-tasbeeh-btn').style.display = 'none';

}

function handleDragStart(e) {
    draggingItem = e.target;
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/html', draggingItem.innerHTML);
    e.target.classList.add('dragging');
}

function handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    const targetItem = e.target.closest('li');
    if (targetItem && targetItem !== draggingItem) {
        const list = targetItem.parentNode;
        const items = [...list.children];
        const draggingIndex = items.indexOf(draggingItem);
        const targetIndex = items.indexOf(targetItem);
        if (draggingIndex > targetIndex) {
            list.insertBefore(draggingItem, targetItem);
        } else {
            list.insertBefore(draggingItem, targetItem.nextSibling);
        }
    }
}

function handleDragLeave(e) {
    e.target.classList.remove('drag-over');
}

function handleDrop(e) {
    e.stopPropagation();
    e.preventDefault();
}

function handleDragEnd(e) {
    e.target.classList.remove('dragging');
    const listElement = document.getElementById('edit-tasbeeh-list');
    const newOrder = Array.from(listElement.children).map(li => li.querySelector('span').textContent);
    saveTasbeehPhrases(newOrder);
    draggingItem = null;
}


elements.goToTasbeehButton.addEventListener("click", () => {
    state.tasbeehSessionCounts = {};
    showPage('tasbeeh-page');
    renderTasbeehPage();
});

elements.tasbeehPage.addEventListener('click', (e) => {
    const backButton = e.target.closest('#back-to-main-menu-from-tasbeeh');
    const tasbeehItem = e.target.closest('.tasbeeh-item');
    const resetButton = e.target.closest('.reset-session');
    const editButton = e.target.closest('#edit-tasbeeh-list-btn');
    const resetAllButton = e.target.closest('#reset-all-tasbeeh-btn');
    const saveButton = e.target.closest('#save-tasbeeh-btn');
    const addButton = e.target.closest('#add-tasbeeh-btn');
    const deleteButton = e.target.closest('.delete-tasbeeh-btn');

    if (backButton) {
        const editPanel = document.getElementById('edit-tasbeeh-panel');
        if (editPanel && editPanel.style.display !== 'none') {
            renderTasbeehPage();
            document.getElementById('edit-tasbeeh-list-btn').style.display = 'flex';
            document.getElementById('reset-all-tasbeeh-btn').style.display = 'flex';
        }
        else {
            showPage('main-menu-page');
        }
        return;
    }

    if (editButton) {
        renderEditTasbeehPanel();
        return;
    }

    if (resetAllButton) {
        if (confirm('هل أنت متأكد أنك تريد تصفير جميع العدادات؟')) {
            state.tasbeehSessionCounts = {};
            localStorage.removeItem('tasbeehTotalCounts');
            renderTasbeehPage();
        }
        return;
    }

    if (resetButton) {
        e.stopPropagation();
        const item = resetButton.closest('.tasbeeh-item');
        const index = item.dataset.index;
        state.tasbeehSessionCounts[index] = 0;
        item.querySelector('.session-counter').textContent = 0;
        return;
    }

    if (addButton) {
        const input = document.getElementById('new-tasbeeh-input');
        const newPhrase = input.value.trim();
        if (newPhrase) {
            const currentPhrases = getTasbeehPhrases();
            if (!currentPhrases.includes(newPhrase)) {
                currentPhrases.push(newPhrase);
                saveTasbeehPhrases(currentPhrases);
                renderEditTasbeehPanel();
                input.value = '';
            } else {
                const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
                const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
                showFloatingMessage(translations['dhikr-already-exists'] || "هذا الذكر موجود بالفعل.", false);
            }
        }
        return;
    }

    if (deleteButton) {
        e.stopPropagation();
        const phraseToDelete = deleteButton.dataset.phrase;
        let currentPhrases = getTasbeehPhrases();
        const indexToDelete = currentPhrases.indexOf(phraseToDelete);
        if (indexToDelete > -1) {
            currentPhrases.splice(indexToDelete, 1);
            saveTasbeehPhrases(currentPhrases);
            renderEditTasbeehPanel();
        }
        return;
    }

    if (saveButton) {
        renderTasbeehPage();
        document.getElementById('edit-tasbeeh-list-btn').style.display = 'flex';
        document.getElementById('reset-all-tasbeeh-btn').style.display = 'flex';
        return;
    }


    if (tasbeehItem) {
        const index = tasbeehItem.dataset.index;
        const tasbeehPhrases = getTasbeehPhrases();
        const phrase = tasbeehPhrases[index];

        if(phrase){
             state.tasbeehSessionCounts[index] = (state.tasbeehSessionCounts[index] || 0) + 1;
             tasbeehItem.querySelector('.session-counter').textContent = state.tasbeehSessionCounts[index];

             let totalCounts = getTasbeehTotalCounts();
             totalCounts[index] = (totalCounts[index] || 0) + 1;
             saveTasbeehTotalCounts(totalCounts);
             tasbeehItem.querySelector('.total-counter').textContent = totalCounts[index];
        }
    }
});
// --- END: Tasbeeh Logic ---

// --- START: Quran Reader Logic ---
// --- Swipe / Drag Navigation for Quran Reader (touch + mouse) ---
function attachReaderSwipeHandlers(container) {
    if (!container) return;
    if (container._hasSwipeHandlers) return;
    container._hasSwipeHandlers = true;

    let startX = 0, startY = 0, isDown = false;
    const H_THRESHOLD = 60, V_THRESHOLD = 50;

    const onTouchStart = (e) => {
        const t = e.touches && e.touches[0]; if (!t) return;
        startX = t.clientX; startY = t.clientY; isDown = true;
    };
    const onTouchEnd = (e) => {
        if (!isDown) return; isDown = false;
        const t = (e.changedTouches && e.changedTouches[0]) || (e.touches && e.touches[0]); if (!t) return;
        const dx = t.clientX - startX, dy = t.clientY - startY;
        if (Math.abs(dy) > Math.abs(dx) && Math.abs(dy) > V_THRESHOLD) return;
        if (Math.abs(dx) >= H_THRESHOLD) {
		if (dx > 0) { // ⬅️➡️ اسحب لليمين ⇒ الصفحة التالية
			if (state.currentQuranPage < TOTAL_QURAN_PAGES) {
				state.currentQuranPage++;
				renderQuranPage(state.currentQuranPage, 'next'); // لو انتقلت لصفحة تالية
				renderQuranPage(state.currentQuranPage, 'prev'); // لو رجعت للصفحة السابقة
			}
		} else { // ➡️⬅️ اسحب لليسار ⇒ الصفحة السابقة
			if (state.currentQuranPage > 1) {
				state.currentQuranPage--;
				renderQuranPage(state.currentQuranPage, 'next'); // لو انتقلت لصفحة تالية
				renderQuranPage(state.currentQuranPage, 'prev'); // لو رجعت للصفحة السابقة
			}
		}
	}
    };

    let mx = 0, my = 0;
    const onMouseDown = (e) => {
        if (e.target.closest('button, a, input, textarea, select')) return;
        const sel = window.getSelection && window.getSelection().toString(); if (sel) return;
        isDown = true; mx = e.clientX; my = e.clientY;
    };
    const onMouseUp = (e) => {
        if (!isDown) return; isDown = false;
        const sel = window.getSelection && window.getSelection().toString(); if (sel) return;
        const dx = e.clientX - mx, dy = e.clientY - my;
        if (Math.abs(dy) > Math.abs(dx) && Math.abs(dy) > V_THRESHOLD) return;
                if (Math.abs(dx) >= H_THRESHOLD) {
		if (dx > 0) { // ⬅️➡️ اسحب لليمين ⇒ الصفحة التالية
			if (state.currentQuranPage < TOTAL_QURAN_PAGES) {
				state.currentQuranPage++;
				renderQuranPage(state.currentQuranPage, 'next'); // لو انتقلت لصفحة تالية
				renderQuranPage(state.currentQuranPage, 'prev'); // لو رجعت للصفحة السابقة
			}
		} else { // ➡️⬅️ اسحب لليسار ⇒ الصفحة السابقة
			if (state.currentQuranPage > 1) {
				state.currentQuranPage--;
				renderQuranPage(state.currentQuranPage, 'next'); // لو انتقلت لصفحة تالية
				renderQuranPage(state.currentQuranPage, 'prev'); // لو رجعت للصفحة السابقة
			}
		}
	}
    };

    container.addEventListener('touchstart', onTouchStart, { passive: true });
    container.addEventListener('touchend', onTouchEnd, { passive: true });
    container.addEventListener('mousedown', onMouseDown);
    window.addEventListener('mouseup', onMouseUp);
}
function attachHadithSwipeHandlers(container) {
    // نتأكد من عدم إضافة المستمعين أكثر من مرة لنفس العنصر
    if (!container || container._hasHadithSwipeHandlers) return;
    container._hasHadithSwipeHandlers = true;

    let startX = 0;
    const H_THRESHOLD = 60; // المسافة الدنيا لاعتبارها سحبة

    // معالجة السحب باللمس
    const onTouchStart = (e) => {
        startX = e.touches[0].clientX;
    };
    
    const onTouchEnd = (e) => {
        const endX = e.changedTouches[0].clientX;
        const dx = endX - startX;

        if (Math.abs(dx) > H_THRESHOLD) {
            if (dx < 0) {
                handleHadithNavigation('prev');
            }
            else {
                handleHadithNavigation('next');
            }
        }
    };
    
    // معالجة السحب بالماوس (للكمبيوتر)
    let isDown = false;
    const onMouseDown = (e) => {
        // تجاهل السحب إذا بدأ على زر أو رابط
        if (e.target.closest('button, a, input')) return;
        isDown = true;
        startX = e.clientX;
    };

    const onMouseUp = (e) => {
        if (!isDown) return;
        isDown = false;
        const endX = e.clientX;
        const dx = endX - startX;

        if (Math.abs(dx) > H_THRESHOLD) {
             if (dx < 0) {
                handleHadithNavigation('prev');
            }
            else {
                handleHadithNavigation('next');
            }
        }
    };

    container.addEventListener('touchstart', onTouchStart, { passive: true });
    container.addEventListener('touchend', onTouchEnd, { passive: true });
    container.addEventListener('mousedown', onMouseDown);
    // نربط حدث mouseup بالنافذة كلها لضمان التقاطه حتى لو خرج المؤشر عن العنصر
    window.addEventListener('mouseup', onMouseUp);
}
async function fetchQuranPageData(pageNumber) {
    // 1. تحديد مفتاح فريد لكل صفحة في الـ cache
    const cacheKey = `quran-page-${pageNumber}`;

    try {
        // 2. محاولة قراءة الصفحة من Local Storage
        const cachedPageData = localStorage.getItem(cacheKey);
        if (cachedPageData) {
            console.log(`Loading page ${pageNumber} from cache.`);
            return JSON.parse(cachedPageData); // إرجاع البيانات المخزنة بعد تحويلها من نص
        }

        // 3. إذا لم تكن موجودة، يتم طلبها من الخادم
        console.log(`Fetching page ${pageNumber} from server.`);
        const pageData = await apiRequest(`/quran/page/${pageNumber}`);
        
        // 4. تخزين الصفحة الجديدة في Local Storage للمرة القادمة
        // يتم تحويل الكائن إلى نص قبل التخزين
        localStorage.setItem(cacheKey, JSON.stringify(pageData));

        return pageData;

    } catch (error) {
        console.error(`Failed to fetch page ${pageNumber}:`, error);
        return { error: `فشل تحميل صفحة ${pageNumber}.` };
    }
}

async function renderQuranPage(pageNumber) {
    const readerPage = elements.quranReaderPage;
    const pageContentDiv = readerPage.querySelector('#quran-page-content');
    
    // لإيقاف الصوت الحالي عند الانتقال لصفحة جديدة
    elements.fullAudioPlayer.pause();

    if (pageContentDiv) {
        pageContentDiv.classList.add('fading-out');
    }

    const data = await fetchQuranPageData(pageNumber);

    setTimeout(() => {
        window.scrollTo(0, 0);
        if (!data || data.error) {
            readerPage.innerHTML = `<p style="text-align:center; padding: 2rem;">${data?.error || (translations['unknown-error'] || 'حدث خطأ ما.')}</p><button id="back-to-menu-from-reader" class="back-button">➡️</button>`;
            document.getElementById('back-to-menu-from-reader').addEventListener('click', () => showPage('main-menu-page'));
            return;
        }

        let contentHTML = '';
        data.surahs.forEach((surah, index) => {
            if (surah.verses[0].numberInSurah === 1) {
                 contentHTML += `<div class="surah-header">${surah.surahName}</div>`;
            }
            
            if (surah.verses[0].numberInSurah === 1 && surah.surahOrder !== 1 && surah.surahOrder !== 9) {
                 contentHTML += `<p class="basmala">بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ</p>`;
            }
            
            contentHTML += `<p class="verse-paragraph">`;
            surah.verses.forEach(verse => {
                contentHTML += `<span class="verse">${verse.text}</span><span class="verse-number">${verse.numberInSurah}</span>`;
            });
            contentHTML += `</p>`;
        });

        readerPage.innerHTML = `
            <div class="quran-page-header">
                <button id="share-quran-page-btn" class="share-button" title="${translations['share-page'] || 'مشاركة الصفحة'}">🔗</button>
                <span id="quran-page-surah-name">${data.surahs[0].surahName}</span>
                <div class="quran-page-audio-controls">
                    <button id="rewind-page-audio-btn" class="quran-page-audio-button" title="${translations['rewind-10s'] || 'تأخير 10 ثواني'}" hidden>⏭️</button>
                    <button id="play-page-audio-btn" class="quran-page-audio-button" title="${translations['play-pause'] || 'تشغيل/إيقاف'}">🔊</button>
                    <button id="forward-page-audio-btn" class="quran-page-audio-button" title="${translations['forward-10s'] || 'تقديم 10 ثواني'}">⏮️</button>
                </div>
                <span id="quran-page-juz-number" class="clickable-juz-number" title="${translations['go-to-juz'] || 'الانتقال إلى جزء'}">الجزء ${data.juz}</span>
            </div>
            <div id="quran-page-content">${contentHTML}</div>
            <div class="quran-page-footer">
                <span id="quran-page-number" class="clickable-page-number" title="${translations['go-to-page'] || 'الانتقال إلى صفحة'}">📖 الصفحة ${pageNumber}</span>
            </div>
            <div class="reader-nav">
                <button id="reader-prev-btn" class="reader-nav-arrow" ${pageNumber <= 1 ? 'disabled' : ''}>الصفحة السابقة ➡️</button>
                <button id="reader-next-btn" class="reader-nav-arrow" ${pageNumber >= TOTAL_QURAN_PAGES ? 'disabled' : ''}>⬅️ ${translations['next-page'] || 'الصفحة التالية'}</button>
            </div>
             <button id="back-to-menu-from-reader" class="back-button" aria-label="${translations['back'] || 'العودة'}">➡️</button>
        `;
		attachReaderSwipeHandlers(readerPage);

        const newPageContentDiv = readerPage.querySelector('#quran-page-content');
        if (newPageContentDiv) {
            newPageContentDiv.classList.add('fading-in');
        }

        // --- START: Share Button Event Listener ---
        document.getElementById('share-quran-page-btn').addEventListener('click', () => {
            const url = `https://qurani.info/page/${pageNumber}`;
            const title = `صفحة من القرآن الكريم - ${data.surahs[0].surahName}`;
            const text = `أشارككم هذه الصفحة من القرآن الكريم (صفحة ${pageNumber}).`;
            showShareModal(url, title, text);
        });
        // --- END: Share Button Event Listener ---

        // --- START: Updated Audio Controls Logic ---
        const playPageBtn = document.getElementById('play-page-audio-btn');
        const rewindBtn = document.getElementById('rewind-page-audio-btn');
        const forwardBtn = document.getElementById('forward-page-audio-btn');
        const audioPlayer = elements.fullAudioPlayer;

        // 1. إخفاء زر التقديم بناءً على طلبك
        forwardBtn.style.display = 'none';

        // 2. متغير لتتبع ما إذا تم التشغيل في هذه الصفحة
        let hasPlayedOnThisPage = false;

        const formattedPageNumber = String(pageNumber).padStart(3, '0');
        const audioSrc = `/data/pages/afs/${formattedPageNumber}.mp3`;

        const updateAudioControlsUI = () => {
            const isPlaying = !audioPlayer.paused && audioPlayer.src.endsWith(audioSrc);
            const isSeekable = audioPlayer.duration && !isNaN(audioPlayer.duration);

            if (isPlaying) {
                playPageBtn.textContent = '⏸️';
            } else {
                playPageBtn.textContent = '🔊';
            }

            // 2. تفعيل زر التأخير فقط إذا كان الصوت جاهزاً وتم التشغيل مرة واحدة
            rewindBtn.disabled = !isSeekable || !hasPlayedOnThisPage;
        };

        playPageBtn.addEventListener('click', () => {
            // عند أول ضغطة تشغيل في الصفحة، يتم تفعيل إمكانية الرجوع
            if (!hasPlayedOnThisPage) {
                hasPlayedOnThisPage = true;
            }

            if (!audioPlayer.src.endsWith(audioSrc)) {
                audioPlayer.src = audioSrc;
                audioPlayer.play().catch(e => console.error("Audio playback failed:", e));
            } else {
                if (audioPlayer.paused) {
                    audioPlayer.play().catch(e => console.error("Audio playback failed:", e));
                } else {
                    audioPlayer.pause();
                }
            }
        });

        rewindBtn.addEventListener('click', () => {
            audioPlayer.currentTime = Math.max(0, audioPlayer.currentTime - 10);
        });
        
        // ربط الأحداث بالدالة المحدثة
        audioPlayer.onplay = updateAudioControlsUI;
        audioPlayer.onpause = updateAudioControlsUI;
        audioPlayer.onended = updateAudioControlsUI;
        audioPlayer.onloadedmetadata = updateAudioControlsUI;
        audioPlayer.ontimeupdate = null; // إزالة المستمع غير الضروري

        // استدعاء الدالة لضبط الحالة الأولية للأزرار عند تحميل الصفحة
        updateAudioControlsUI();
        // --- END: Updated Audio Controls Logic ---

        document.getElementById('reader-next-btn').addEventListener('click', () => {
            if (state.currentQuranPage < TOTAL_QURAN_PAGES) {
                state.currentQuranPage++;
                renderQuranPage(state.currentQuranPage);
            }
        });
        document.getElementById('reader-prev-btn').addEventListener('click', () => {
             if (state.currentQuranPage > 1) {
                state.currentQuranPage--;
                renderQuranPage(state.currentQuranPage);
            }
        });
         document.getElementById('back-to-menu-from-reader').addEventListener('click', () => showPage('main-menu-page'));
         document.getElementById('quran-page-number').addEventListener('click', showGoToPageModal);
         document.getElementById('quran-page-surah-name').addEventListener('click', showGoToSurahModal);
         document.getElementById('quran-page-juz-number').addEventListener('click', showGoToJuzModal);

    }, 200);
}


function showGoToPageModal() {
    if (elements.goToPageOverlay) {
        elements.goToPageInput.value = state.currentQuranPage;
        elements.goToPageInput.max = TOTAL_QURAN_PAGES;
        elements.goToPageOverlay.style.display = 'flex';
        elements.goToPageInput.focus();
        elements.goToPageInput.select();
    }
}

function hideGoToPageModal() {
    if (elements.goToPageOverlay) {
        elements.goToPageOverlay.style.display = 'none';
    }
}

function handleGoToPage() {
    const pageNumber = parseInt(elements.goToPageInput.value, 10);
    if (isNaN(pageNumber) || pageNumber < 1 || pageNumber > TOTAL_QURAN_PAGES) {
        showFloatingMessage(`الرجاء إدخال رقم صفحة صحيح بين 1 و ${TOTAL_QURAN_PAGES}.`, false);
        return;
    }
    state.currentQuranPage = pageNumber;
    renderQuranPage(state.currentQuranPage);
    hideGoToPageModal();
}

// --- START: Share Logic ---
function showShareModal(url, title, text) {
    if (navigator.share) {
        // Use Web Share API if available
        navigator.share({
            title: title,
            text: text,
            url: url
        })
        .catch((error) => console.log('Error sharing:', error));
    } else {
        // Fallback to custom modal for desktop
        elements.shareUrlInput.value = url;
        
        const encodedUrl = encodeURIComponent(url);
        const encodedText = encodeURIComponent(text);

        elements.shareWhatsapp.href = `https://api.whatsapp.com/send?text=${encodedText}%20${encodedUrl}`;
        elements.shareTelegram.href = `https://t.me/share/url?url=${encodedUrl}&text=${encodedText}`;
        elements.shareTwitter.href = `https://twitter.com/intent/tweet?url=${encodedUrl}&text=${encodedText}`;
        elements.shareFacebook.href = `https://www.facebook.com/sharer/sharer.php?u=${encodedUrl}`;

        elements.shareModalOverlay.style.display = 'flex';
        document.body.classList.add('modal-open');
    }
}
// --- END: Share Logic ---

// --- START: Go to Surah Modal Logic ---
function populateSurahList(surahsToDisplay) {
    elements.goToSurahList.innerHTML = '';
    if (!surahsToDisplay || surahsToDisplay.length === 0) {
        elements.goToSurahList.innerHTML = '<li>لا توجد سور مطابقة للبحث.</li>';
        return;
    }

    surahsToDisplay.forEach(surah => {
        const li = document.createElement('li');
        li.textContent = `${surah.surah_order}. ${surah.surah_name}`;
        // هنا نستخدم الخريطة الجديدة لجلب رقم الصفحة وتخزينه
        li.dataset.startPage = SURAH_START_PAGES[surah.surah_order]; 
        elements.goToSurahList.appendChild(li);
    });
}

function showGoToSurahModal() {
    if (elements.goToSurahOverlay) {
        populateSurahList(state.surahs);
        elements.goToSurahInput.value = '';
        elements.goToSurahOverlay.style.display = 'flex';
        elements.goToSurahInput.focus();
    }
}
// --- START: Go to Juz Modal Logic ---
function populateJuzList() {
    elements.goToJuzList.innerHTML = '';
    for (let i = 1; i <= 28; i++) {
        const li = document.createElement('li');
        li.textContent = `الجزء ${i}`;
        li.dataset.startPage = JUZ_START_PAGES[i];
        elements.goToJuzList.appendChild(li);
    }
    const li29 = document.createElement('li');
    li29.textContent = `29- جزء تبارك`;
    li29.dataset.startPage = JUZ_START_PAGES[29];
    elements.goToJuzList.appendChild(li29);

    
    const li30 = document.createElement('li');
    li30.textContent = `30- جزء عم`;
    li30.dataset.startPage = JUZ_START_PAGES[30];
    elements.goToJuzList.appendChild(li30);
}

function showGoToJuzModal() {
    if (elements.goToJuzOverlay) {
        populateJuzList();
        elements.goToJuzOverlay.style.display = 'flex';
    }
}

function hideGoToJuzModal() {
    if (elements.goToJuzOverlay) {
        elements.goToJuzOverlay.style.display = 'none';
    }
}
// --- END: Go to Juz Modal Logic ---
function hideGoToSurahModal() {
    if (elements.goToSurahOverlay) {
        elements.goToSurahOverlay.style.display = 'none';
    }
}
// --- END: Go to Surah Modal Logic ---

elements.goToReaderButton.addEventListener("click", () => {
    state.currentQuranPage = 1;
    showPage('quran-reader-page');
    renderQuranPage(state.currentQuranPage);
});
// --- END: Quran Reader Logic ---


elements.backToMenuFromLobbyButton.addEventListener("click", () => showPage('main-menu-page'));
elements.result.addEventListener('click', (event) => {
    if (event.target.id === 'play-again-button') {
        elements.result.style.display = 'none';

        document.querySelector('.tab-menu').style.display = 'flex';
        document.getElementById('start-game-button').style.display = 'block';
        document.getElementById('total-score-display').style.display = 'block';

        elements.tabButtons.forEach(btn => btn.classList.remove('active'));
        document.querySelector('.tab-button[data-tab="surah-tab"]').classList.add('active');

        document.querySelector('#surah-tab').style.display = 'block';
        document.querySelector('#juz-tab').style.display = 'none';
        state.currentGameType = 'surah';
        
        if (elements.juzSelect) {
            elements.juzSelect.selectedIndex = 0;
        }
        
        showPage('game-lobby-page');
    }
    else if (event.target.id === 'return-to-menu-button') {
        showPage('main-menu-page');
        elements.result.style.display = 'none';
    }
});
elements.showOnLeaderboardCheckbox.addEventListener('change', async (event) => {
    const isChecked = event.target.checked;
    try {
        await apiRequest('/user/preference', {
            method: 'POST',
            body: JSON.stringify({ showOnLeaderboard: isChecked })
        });
        const message = isChecked ? 'تم عرض اسمك في قائمة المتصدرين بنجاح.' : 'تم إخفاء اسمك من قائمة المتصدرين بنجاح.';
        showFloatingMessage(message, isChecked);
        loadInitialData();
    } catch (error) {
        console.error("Failed to update user preference:", error);
        showFloatingMessage(translations['preference-update-failed'] || "فشل في تحديث التفضيل. يرجى المحاولة مرة أخرى.", false);
        elements.showOnLeaderboardCheckbox.checked = !isChecked;
    }
});
if(isTelegram) tg.onEvent('backButtonClicked', () => showEndMessage());
elements.pauseButton.addEventListener('click', pauseGame);
elements.resumeButton.addEventListener('click', resumeGame);

elements.endGameButton.addEventListener('click', (e) => {
    e.stopPropagation();
    clearInterval(state.questionTimerInterval);
    elements.confirmEndOverlay.style.display = 'flex';
});

elements.confirmEndNo.addEventListener('click', (e) => {
    e.stopPropagation();
    elements.confirmEndOverlay.style.display = 'none';
    startQuestionTimer(timeLeft);
});

elements.confirmEndYes.addEventListener('click', (e) => {
    e.stopPropagation();
    showEndMessage();
});

// Theme Dropdown Logic
const themeDropdownButton = document.getElementById('theme-dropdown-button');
const themeDropdownMenu = document.getElementById('theme-dropdown-menu');
const themeOptions = themeDropdownMenu.querySelectorAll('.theme-option');
const themeText = themeDropdownButton.querySelector('.theme-text');

// Language Dropdown Logic
const languageDropdownButton = document.getElementById('language-dropdown-button');
const languageDropdownMenu = document.getElementById('language-dropdown-menu');
const languageOptions = languageDropdownMenu.querySelectorAll('.language-option');
const languageText = languageDropdownButton.querySelector('.language-text');

// Theme data mapping
const themeData = {
    'default': { emoji: '💜', name: 'افتراضي' },
    'night': { emoji: '🌙', name: 'ليلي' },
    'sky': { emoji: '☁️', name: 'سماوي' },
    'pink': { emoji: '🌸', name: 'زهري' }
};

// Language data mapping
const languageData = {
    'ar': { flag: '🇸🇾', name: 'العربية' },
    'en': { flag: '🇺🇸', name: 'English' },
    'fr': { flag: '🇫🇷', name: 'Français' }
};

function setTheme(themeName) {
    document.body.setAttribute('data-theme', themeName);
    localStorage.setItem('gameTheme', themeName);
    
    // Update dropdown button text using translations
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const currentTranslations = translations[currentLanguage];
    const theme = themeData[themeName];
    const translatedThemeName = currentTranslations[`theme-${themeName}`] || theme.name;
    themeText.innerHTML = `${theme.emoji} ${translatedThemeName}`;
    
    // Update active option
    themeOptions.forEach(option => {
        option.classList.toggle('active', option.dataset.theme === themeName);
    });
    
    // Close dropdown
    closeThemeDropdown();
}

function loadSavedTheme() {
    setTheme(localStorage.getItem('gameTheme') || 'default');
}

function setLanguage(languageCode) {
    document.documentElement.setAttribute('lang', languageCode);
    document.body.setAttribute('data-lang', languageCode);
    localStorage.setItem('appLanguage', languageCode);
    
    // Update dropdown button text - use the translated name
    const language = languageData[languageCode];
    const translatedName = translations[languageCode][`language-${languageCode}`] || language.name;
    languageText.innerHTML = `${language.flag} ${translatedName}`;
    
    // Update active option
    languageOptions.forEach(option => {
        option.classList.toggle('active', option.dataset.language === languageCode);
    });
    
    // Apply translations to all elements
    applyTranslations(languageCode);
    
    // Clear and reload surah data with new language
    state.surahs = [];
    refreshSurahData();
    
    // Close dropdown
    closeLanguageDropdown();
}

// Function to load surah data directly from JavaScript files
async function loadSurahData(language = null) {
    try {
        const currentLanguage = language || localStorage.getItem('appLanguage') || 'ar';
        
        // Choose the appropriate file based on language
        const filename = (currentLanguage === 'en' || currentLanguage === 'fr') 
            ? 'surah_list_latin.js' 
            : 'surah_list.js';
        
        console.log(`🔄 Loading surahs from ${filename} for language: ${currentLanguage}`);
        
        // Use dynamic script loading instead of fetch
        return new Promise((resolve, reject) => {
            // Remove any existing script with the same src
            const existingScript = document.querySelector(`script[src="${filename}"]`);
            if (existingScript) {
                existingScript.remove();
            }
            
            // Clear the previous surahList to avoid conflicts
            window.surahList = null;
            
            const script = document.createElement('script');
            script.src = filename;
            script.onload = () => {
                if (window.surahList && Array.isArray(window.surahList)) {
                    console.log(`✅ Successfully loaded ${window.surahList.length} surahs from ${filename}`);
                    resolve(window.surahList);
                } else {
                    reject(new Error('surahList not found or not an array'));
                }
            };
            script.onerror = () => {
                reject(new Error(`Failed to load ${filename}`));
            };
            document.head.appendChild(script);
        });
        
    } catch (error) {
        console.error('❌ Failed to load surah data:', error);
        // Return empty array as fallback
        return [];
    }
}

// Function to refresh surah data with current language
async function refreshSurahData() {
    try {
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const surahs = await loadSurahData(currentLanguage);
        state.surahs = surahs;
        
        // Update selected surah name if one is currently selected
        if (state.selectedSurah && state.selectedSurahOrder) {
            const updatedSurah = surahs.find(s => s.surah_order === state.selectedSurahOrder);
            if (updatedSurah) {
                state.selectedSurah = updatedSurah.surah_name;
            }
        }
        
        // Update recitation selected surah if one is currently selected
        if (state.recitation.selectedSurah) {
            const updatedRecitationSurah = surahs.find(s => s.surah_order === state.recitation.selectedSurah.surah_order);
            if (updatedRecitationSurah) {
                state.recitation.selectedSurah = updatedRecitationSurah;
            }
        }
        
        // If we're currently on a page that displays surahs, refresh the display
        const currentPage = document.querySelector('.page:not([style*="display: none"])');
        if (currentPage) {
            const pageId = currentPage.id;
            if (pageId === 'tafsir-page' || pageId === 'audio-page' || pageId === 'full-audio-page') {
                // Refresh the surah selection display
                const type = pageId === 'audio-page' ? 'audio' : 'tafsir';
                renderSurahSelection(type);
            } else if (pageId === 'recitation-page' && state.recitation.selectedSurah) {
                // Refresh recitation page header
                const headerElement = elements.recitationPage.querySelector('.page-header h2');
                if (headerElement) {
                    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
                    const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
                    headerElement.textContent = `${translations['recitation'] || 'تسميع'} ${state.recitation.selectedSurah.surah_name}`;
                }
            } else if (pageId === 'game-lobby-page') {
                // Update Juz names translation
                updateJuzNamesTranslation();
            }
        }
    } catch (error) {
        console.error('Failed to refresh surah data:', error);
    }
}

// دالة تطبيق الترجمة على جميع العناصر
function applyTranslations(languageCode) {
    const currentTranslations = translations[languageCode];
    if (!currentTranslations) return;
    
    // تطبيق الترجمة على جميع العناصر التي تحتوي على data-translate
    document.querySelectorAll('[data-translate]').forEach(element => {
        const key = element.getAttribute('data-translate');
        const number = element.getAttribute('data-number');
        
        if (currentTranslations[key]) {
            // إذا كان العنصر يحتوي على رقم (للأجزاء)، أضف الرقم
            if (number) {
                element.innerHTML = currentTranslations[key] + ' ' + number;
            } else {
                // استخدم الترجمة مباشرة
                element.innerHTML = currentTranslations[key];
            }
        }
    });
    
    // تطبيق الترجمة على placeholder attributes
    document.querySelectorAll('[data-translate-placeholder]').forEach(element => {
        const key = element.getAttribute('data-translate-placeholder');
        if (currentTranslations[key]) {
            element.placeholder = currentTranslations[key];
        }
    });
    
    // تحديث زر اللغة بشكل خاص
    const language = languageData[languageCode];
    const translatedName = currentTranslations[`language-${languageCode}`] || language.name;
    languageText.innerHTML = `${language.flag} ${translatedName}`;
    
    // تحديث ترجمات أزرار إظهار/إخفاء كلمة المرور
    document.querySelectorAll('.password-toggle-btn').forEach(button => {
        const isPasswordVisible = button.textContent === '🙈';
        if (isPasswordVisible) {
            button.title = currentTranslations['hide-password'] || 'إخفاء كلمة المرور';
        } else {
            button.title = currentTranslations['show-password'] || 'إظهار كلمة المرور';
        }
    });
    
    // تحديث اسم الثيم المختار في زر الاختيار
    const currentTheme = localStorage.getItem('gameTheme') || 'default';
    const theme = themeData[currentTheme];
    const translatedThemeName = currentTranslations[`theme-${currentTheme}`] || theme.name;
    themeText.innerHTML = `${theme.emoji} ${translatedThemeName}`;
    
    // تحديث النصوص الخاصة بعلامات الاستفهام
    updateQuestionMarks(languageCode);
    
    // تحديث اتجاه النص حسب اللغة
    if (languageCode === 'ar') {
        document.documentElement.setAttribute('dir', 'rtl');
    } else {
        document.documentElement.setAttribute('dir', 'ltr');
    }
}

// دالة الحصول على الترجمة الحالية
function getTranslation(key) {
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const currentTranslations = translations[currentLanguage];
    return currentTranslations[key] || key;
}

// دالة تحديث علامات الاستفهام المناسبة لكل لغة
function updateQuestionMarks(languageCode) {
    const currentTranslations = translations[languageCode];
    if (!currentTranslations) return;
    
    // تحديث رابط نسيت كلمة المرور
    const forgotPasswordLink = document.getElementById('forgot-password-link');
    if (forgotPasswordLink) {
        const key = 'forgot-password';
        if (currentTranslations[key]) {
            forgotPasswordLink.innerHTML = currentTranslations[key];
        }
    }
    
    // تحديث رابط إنشاء الحساب
    const toggleFormLink = document.getElementById('toggle-form-link');
    if (toggleFormLink) {
        const key = 'no-account';
        if (currentTranslations[key]) {
            toggleFormLink.innerHTML = currentTranslations[key];
        }
    }
    
    // تحديث رابط إنشاء الحساب في الصفحة الرئيسية
    const guestRegisterLink = document.getElementById('guest-register-link');
    if (guestRegisterLink) {
        const key = 'no-account';
        if (currentTranslations[key]) {
            guestRegisterLink.innerHTML = currentTranslations[key];
        }
    }
}

function loadSavedLanguage() {
    const savedLanguage = localStorage.getItem('appLanguage') || 'ar';
    setLanguage(savedLanguage);
}

function openThemeDropdown() {
    themeDropdownMenu.classList.add('show');
    themeDropdownButton.classList.add('open');
}

function closeThemeDropdown() {
    themeDropdownMenu.classList.remove('show');
    themeDropdownButton.classList.remove('open');
}

function openLanguageDropdown() {
    languageDropdownMenu.classList.add('show');
    languageDropdownButton.classList.add('open');
}

function closeLanguageDropdown() {
    languageDropdownMenu.classList.remove('show');
    languageDropdownButton.classList.remove('open');
}

// Event listeners
themeDropdownButton.addEventListener('click', (e) => {
    e.stopPropagation();
    if (themeDropdownMenu.classList.contains('show')) {
        closeThemeDropdown();
    } else {
        openThemeDropdown();
    }
});

themeOptions.forEach(option => {
    option.addEventListener('click', () => {
        setTheme(option.dataset.theme);
    });
});

// Language dropdown event listeners
languageDropdownButton.addEventListener('click', (e) => {
    e.stopPropagation();
    if (languageDropdownMenu.classList.contains('show')) {
        closeLanguageDropdown();
    } else {
        openLanguageDropdown();
    }
});

languageOptions.forEach(option => {
    option.addEventListener('click', () => {
        setLanguage(option.dataset.language);
    });
});

// Close dropdowns when clicking outside
document.addEventListener('click', (e) => {
    if (!themeDropdownButton.contains(e.target) && !themeDropdownMenu.contains(e.target)) {
        closeThemeDropdown();
    }
    if (!languageDropdownButton.contains(e.target) && !languageDropdownMenu.contains(e.target)) {
        closeLanguageDropdown();
    }
});

// --- Admin Page Logic ---
async function loadAdminPage() {
    showPage('admin-page');
    await loadMessages();
}
// --- Recitation Page Logic ---
async function loadRecitationPage() {
    showPage('recitation-page');
    await renderRecitationPage();
}

async function loadMessages() {
    elements.messageList.innerHTML = '<li>جاري تحميل الرسائل...</li>';
    try {
        const messages = await apiRequest('/admin/messages');
        renderMessages(messages);
    } catch (error) {
        console.error("Failed to load messages:", error);
        showFloatingMessage(translations['scheduled-messages-load-failed'] || "فشل تحميل قائمة الرسائل المجدولة.", false);
        elements.messageList.innerHTML = '<li>فشل تحميل الرسائل.</li>';
    }
}

function renderMessages(messages) {
    elements.messageList.innerHTML = '';
    if (messages.length === 0) {
        elements.messageList.innerHTML = '<li>لا توجد رسائل مجدولة حالياً.</li>';
        return;
    }
    messages.forEach(msg => {
        const li = document.createElement('li');
        li.className = 'message-item';
        const scheduledTime = new Date(msg.messagetime).toLocaleString('ar-EG');
        const sentTime = msg.SentTime ? new Date(msg.SentTime).toLocaleString('ar-EG') : 'لم يتم الإرسال';
        const enabled = msg.SentTime ? false : true;

        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
        li.innerHTML = `
            <p>${msg.messagetext}</p>
            <span class="message-meta">وقت الإرسال المجدول: ${scheduledTime}</span>
            <span class="message-meta">وقت الإرسال الفعلي: ${sentTime}</span>
            <div class="action-buttons">
                <button class="edit-btn" data-id="${msg.messageid}" data-text="${msg.messagetext}" data-time="${msg.messagetime}" ${enabled ? '' : 'hidden'}>تعديل</button>
                <button class="delete-btn" data-id="${msg.messageid}">${translations['delete'] || 'حذف'}</button>
            </div>
        `;
        elements.messageList.appendChild(li);
    });
}

function openMessageForm(message = null) {
    elements.messageForm.style.display = 'flex';
    if (message) {
        elements.messageIdInput.value = message.messageid;
        elements.messageTextInput.value = message.messagetext;
        const dateObj = new Date(message.messagetime);
        const year = dateObj.getFullYear();
        const month = String(dateObj.getMonth() + 1).padStart(2, '0');
        const day = String(dateObj.getDate()).padStart(2, '0');
        const hours = String(dateObj.getHours()).padStart(2, '0');
        const minutes = String(dateObj.getMinutes()).padStart(2, '0');
        elements.messageTimeInput.value = `${year}-${month}-${day}T${hours}:${minutes}`;
        elements.saveMessageBtn.textContent = 'حفظ التعديلات';
    } else {
        elements.messageIdInput.value = '';
        elements.messageTextInput.value = '';
        elements.messageTimeInput.value = '';
        elements.saveMessageBtn.textContent = 'إضافة';
    }
}

async function saveMessage() {
    const messageId = elements.messageIdInput.value;
    const messagetext = elements.messageTextInput.value;
    const messagetime = elements.messageTimeInput.value;

    if (!messagetext || !messagetime) {
        showFloatingMessage(translations['message-text-time-required'] || "الرجاء إدخال نص الرسالة ووقت الإرسال.", false);
        return;
    }

    const payload = {
        messagetext: messagetext,
        messagetime: messagetime
    };

    try {
        if (messageId) {
            await apiRequest(`/admin/messages/${messageId}`, {
                method: 'PUT',
                body: JSON.stringify(payload)
            });
            showFloatingMessage(translations['message-modified-success'] || "تم تعديل الرسالة بنجاح.");
        } else {
            await apiRequest('/admin/messages', {
                method: 'POST',
                body: JSON.stringify(payload)
            });
            showFloatingMessage(translations['message-added-success'] || "تمت إضافة الرسالة بنجاح.");
        }
        elements.messageForm.style.display = 'none';
        await loadMessages();
    } catch (error) {
        console.error("Failed to save message:", error);
        showFloatingMessage(`فشل حفظ الرسالة: ${error.message}`, false);
    }
}

async function deleteMessage(messageId) {
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
    
    if (!confirm(translations['confirm-delete'] || "هل أنت متأكد من حذف هذه الرسالة؟")) {
        return;
    }
    try {
        await apiRequest(`/admin/messages/${messageId}`, { method: 'DELETE' });
        showFloatingMessage(translations['message-deleted'] || "تم حذف الرسالة بنجاح.");
        await loadMessages();
    } catch (error) {
        console.error("Failed to delete message:", error);
        showFloatingMessage(`${translations['delete-failed'] || 'فشل حذف الرسالة:'} ${error.message}`, false);
    }
}

elements.goToAdminButton.addEventListener('click', loadAdminPage);
elements.goToRecitationButton.addEventListener('click', loadRecitationPage);
elements.addMessageBtn.addEventListener('click', () => openMessageForm());
elements.cancelEditBtn.addEventListener('click', () => elements.messageForm.style.display = 'none');
elements.saveMessageBtn.addEventListener('click', saveMessage);
elements.adminPage.addEventListener('click', (e) => {
    if (e.target.classList.contains('edit-btn')) {
        const message = {
            messageid: e.target.dataset.id,
            messagetext: e.target.dataset.text,
            messagetime: e.target.dataset.time
        };
        openMessageForm(message);
    } else if (e.target.classList.contains('delete-btn')) {
        deleteMessage(e.target.dataset.id);
    } else if (e.target.id === 'back-to-menu-from-admin') {
        showPage('main-menu-page');
    }
});

// --- Search Page Logic ---
elements.goToSearchButton.addEventListener("click", () => showPage('search-page'));
elements.backToMenuFromSearch.addEventListener("click", () => showPage('main-menu-page'));
elements.searchButton.addEventListener("click", performSearch);
elements.searchInput.addEventListener("keypress", (e) => {
    if (e.key === 'Enter') {
        performSearch();
    }
});

function normalizeArabicText(text) {
    if (!text) return '';
    // إزالة التشكيل
    text = text.replace(/[\u064B-\u0652]/g, "");
    // إزالة الكشيدة (التطويل)
    text = text.replace(/\u0640/g, "");
    // توحيد صور الألف
    text = text.replace(/[أإآٱ]/g, "ا");
    // توحيد التاء المربوطة بالهاء
    text = text.replace(/ة/g, "ه");
    // توحيد الألف المقصورة بالياء
    text = text.replace(/ى/g, "ي");
    return text;
}


async function performSearch() {
    const query = elements.searchInput.value.trim();
    if (query.length < 2) {
        showFloatingMessage(translations['search-minimum-chars'] || "يرجى إدخال كلمة أو جملة لا تقل عن حرفين.", false);
        return;
    }

    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const currentTranslations = translations[currentLanguage];
    
    elements.searchResultsList.innerHTML = `<li>${currentTranslations['search-loading']} "${query}"...</li>`;
    elements.searchResultsCount.style.display = 'none';

    try {
        const results = await apiRequest(`/search?query=${encodeURIComponent(query)}`);
        renderSearchResults(results, query);
    } catch (error) {
        console.error("Failed to fetch search results:", error);
        showFloatingMessage(currentTranslations['search-failed'], false);
        elements.searchResultsList.innerHTML = `<li>${currentTranslations['search-failed']}</li>`;
    }
}

function renderSearchResults(results, query) {
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const currentTranslations = translations[currentLanguage];
    
    elements.searchResultsList.innerHTML = '';
    elements.searchResultsCount.style.display = 'block';

    if (results.length === 0) {
        elements.searchResultsCount.textContent = `${currentTranslations['search-no-results']} "${query}".`;
        return;
    }
    
    elements.searchResultsCount.textContent = `${currentTranslations['search-results-found']} ${results.length} ${currentTranslations['search-results-for']} "${query}".`;
    
    state.searchResults = results;
    state.searchExpandedState = {};
    
    results.forEach((result, index) => {
        const li = document.createElement('li');
        li.className = 'search-result-item';
        li.dataset.index = index;
        
        const highlightedText = highlightSearchTerm(result.verse_text, query);
        
        li.innerHTML = `
            <div class="search-verse-text">${highlightedText}</div>
            <div class="search-info-panel">
                <div style="font-weight:bold;">${result.verse_text}</div>
                <span class="search-result-meta">
                    ${result.surah_name} (${result.surah_order}) | الآية ${result.numberinsurah} | الجزء ${result.juz} | الصفحة ${result.page}
                </span>
                <button class="search-play-button" data-surah-order="${result.surah_order}" data-ayah-number="${result.numberinsurah}" aria-label="${translations['play-verse'] || 'تشغيل الآية'}">
                    ▶️ ${currentTranslations['play-ayah']}
                </button>
            </div>
        `;
        elements.searchResultsList.appendChild(li);
    });
}

function highlightSearchTerm(text, query) {
    const normalizedQuery = normalizeArabicText(query.trim());
    if (!normalizedQuery) return text;

    // Create a regex pattern that accounts for character variations.
    const pattern = normalizedQuery.split('').map(char => {
        if (char === 'ا') return '[أإآاٱ]';
        if (char === 'ه') return '[هة]';
        if (char === 'ي') return '[يى]';
        return char;
    }).join('[\\u064B-\\u0652\\u0640]*'); // Allow diacritics/kashida between letters.

    try {
        const regex = new RegExp(`(${pattern})`, 'gi');
        return text.replace(regex, '<mark class="highlight">$1</mark>');
    } catch (e) {
        console.error("Regex error during highlight:", e);
        return text;
    }
}

elements.searchResultsList.addEventListener('click', (e) => {
    // التحقق من النقر على زر التشغيل
    if (e.target.classList.contains('search-play-button')) {
        e.stopPropagation(); // منع فتح/إغلاق التفاصيل
        
        // إذا كان الزر في حالة تشغيل، أوقف التشغيل
        if (e.target.classList.contains('playing')) {
            if (state.currentAudio) {
                state.currentAudio.pause();
                state.currentAudio = null;
            }
            const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
            const currentTranslations = translations[currentLanguage];
            e.target.innerHTML = `▶️ ${currentTranslations['play-ayah']}`;
            e.target.classList.remove('playing');
            e.target.style.background = '';
            e.target.style.boxShadow = '';
            return;
        }
        
        const surahOrder = e.target.dataset.surahOrder;
        const ayahNumber = e.target.dataset.ayahNumber;
        playSearchResultAudio(e.target, surahOrder, ayahNumber);
        return;
    }

    const item = e.target.closest('.search-result-item');
    if (!item) return;

    const index = item.dataset.index;
    const infoPanel = item.querySelector('.search-info-panel');
    const isExpanded = state.searchExpandedState[index];
    
    elements.searchResultsList.querySelectorAll('.search-result-item.expanded').forEach(expandedItem => {
        if (expandedItem !== item) {
            const expandedPanel = expandedItem.querySelector('.search-info-panel');
            expandedPanel.style.display = 'none';
            expandedItem.classList.remove('expanded');
            state.searchExpandedState[expandedItem.dataset.index] = false;
        }
    });

    if (isExpanded) {
        infoPanel.style.display = 'none';
        item.classList.remove('expanded');
    } else {
        infoPanel.style.display = 'block';
        item.classList.add('expanded');
    }

    state.searchExpandedState[index] = !isExpanded;
});

// دالة تشغيل صوت نتيجة البحث
function playSearchResultAudio(playButton, surahOrder, ayahNumber) {
    // إيقاف أي صوت آخر يعمل
    if (state.currentAudio) {
        state.currentAudio.pause();
        state.currentAudio = null;
    }
    
    // إعادة تعيين جميع أزرار التشغيل الأخرى
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const currentTranslations = translations[currentLanguage];
    
    document.querySelectorAll('.search-play-button').forEach(btn => {
        btn.innerHTML = `▶️ ${currentTranslations['play-ayah']}`;
        btn.classList.remove('playing');
        btn.style.background = '';
        btn.style.boxShadow = '';
    });
    
    // تنسيق رقم السورة والآية بثلاث خانات
    const formattedSurah = surahOrder.toString().padStart(3, '0');
    const formattedAyah = ayahNumber.toString().padStart(3, '0');
    
    // مسار الملف الصوتي
    const audioPath = `/data/ayahs/afs/${formattedSurah}${formattedAyah}.mp3`;
    
    // إنشاء عنصر الصوت
    const audio = new Audio(audioPath);
    state.currentAudio = audio;
    
    // تحديث الزر ليعكس حالة التشغيل
    playButton.innerHTML = `⏸️ ${currentTranslations['pause-ayah']}`;
    playButton.classList.add('playing');
    playButton.style.background = 'linear-gradient(135deg, #ee5a24 0%, #ff6b35 100%)';
    playButton.style.boxShadow = '0 4px 15px rgba(238, 90, 36, 0.3)';
    
    // إضافة معالجات الأحداث
    audio.onended = function() {
        playButton.innerHTML = `▶️ ${currentTranslations['play-ayah']}`;
        playButton.classList.remove('playing');
        playButton.style.background = '';
        playButton.style.boxShadow = '';
        state.currentAudio = null;
    };
    
    audio.onerror = function() {
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const currentTranslations = translations[currentLanguage];
        showFloatingMessage(currentTranslations['audio-error'], false);
        playButton.innerHTML = `▶️ ${currentTranslations['play-ayah']}`;
        playButton.classList.remove('playing');
        playButton.style.background = '';
        playButton.style.boxShadow = '';
        state.currentAudio = null;
    };
    
    // تشغيل الصوت
    audio.play().catch(error => {
        console.error('Error playing audio:', error);
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const currentTranslations = translations[currentLanguage];
        showFloatingMessage(currentTranslations['audio-failed'], false);
        playButton.innerHTML = `▶️ ${currentTranslations['play-ayah']}`;
        playButton.classList.remove('playing');
        playButton.style.background = '';
        playButton.style.boxShadow = '';
        state.currentAudio = null;
    });
}

// --- NEW: Login/Register Handlers ---
async function handleLogin() {
    const username = elements.loginUsernameInput.value.trim();
    const password = elements.loginPasswordInput.value.trim();
    if (!username || !password) {
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
        showFloatingMessage(translations['email-password-required'] || "الرجاء إدخال البريد الإلكتروني وكلمة المرور.", false);
        return;
    }
    try {
        const userData = await apiRequest('/login', {
            method: 'POST',
            body: JSON.stringify({ username, password })
        });
        state.webUserId = userData.UserId;
        state.isGuest = false;
        state.userFullName = userData.UserFullName;
        localStorage.setItem('webUserId', userData.UserId);
        updateUIForUserStatus();
        showPage('main-menu-page');
    } catch (error) {
        showFloatingMessage(`${translations['login-failed'] || 'فشل تسجيل الدخول:'} ${error.message}`, false);
    }
}

async function handleRegister() {
    const email = elements.loginUsernameInput.value.trim();
    const password = elements.loginPasswordInput.value.trim();
    const fullName = elements.registerFullNameInput.value.trim();
    const confirmPassword = document.getElementById('register-confirmPassword').value.trim();
    
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
        showFloatingMessage(translations['valid-email-required'] || "الرجاء إدخال بريد إلكتروني صالح.", false);
        return;
    }

    if (password !== confirmPassword) {
        showFloatingMessage(translations['passwords-not-match'] || "كلمتا المرور غير متطابقتين.", false);
        return;
    }

    if (!email || !password || !fullName) {
        showFloatingMessage(translations['all-fields-required'] || "الرجاء ملء جميع الحقول.", false);
        return;
    }

    try {
        const userData = await apiRequest('/register', {
            method: 'POST',
            body: JSON.stringify({ username: email, password, fullName })
        });
        state.webUserId = userData.UserId;
        state.isGuest = false;
        state.userFullName = userData.UserFullName;
        localStorage.setItem('webUserId', userData.UserId);
        updateUIForUserStatus();
        showPage('main-menu-page');
    } catch (error) {
        showFloatingMessage(`فشل إنشاء الحساب: ${error.message}`, false);
    }
}

async function handleVerifyIdentity() {
    const email = elements.forgotPasswordEmail.value.trim();
    const name = elements.forgotPasswordName.value.trim();
    
    if (!email || !name) {
        showFloatingMessage(translations['email-name-required'] || "الرجاء إدخال البريد الإلكتروني والاسم.", false);
        return;
    }

    try {
        const result = await apiRequest('/verify-identity', {
            method: 'POST',
            body: JSON.stringify({ email, name })
        });
        
        if (result.success) {
            showFloatingMessage(translations['identity-verified-success'] || "تم التحقق من الهوية بنجاح.", true);
            // Hide verification step and show reset password step
            elements.verifyIdentityStep.style.display = 'none';
            elements.resetPasswordStep.style.display = 'block';
        } else {
            showFloatingMessage(translations['email-name-incorrect'] || "البريد الإلكتروني أو الاسم غير صحيح.", false);
        }
    } catch (error) {
        showFloatingMessage(`فشل في التحقق من الهوية: ${error.message}`, false);
    }
}

async function handleResetPassword() {
    const email = elements.forgotPasswordEmail.value.trim();
    const newPassword = elements.newPassword.value.trim();
    const confirmPassword = elements.confirmNewPassword.value.trim();
    
    if (!newPassword || !confirmPassword) {
        showFloatingMessage(translations['new-password-required'] || "الرجاء إدخال كلمة المرور الجديدة.", false);
        return;
    }
    
    if (newPassword !== confirmPassword) {
        showFloatingMessage(translations['passwords-not-match'] || "كلمتا المرور غير متطابقتين.", false);
        return;
    }
    
    if (newPassword.length < 6) {
        showFloatingMessage(translations['password-minimum-length'] || "كلمة المرور يجب أن تكون 6 أحرف على الأقل.", false);
        return;
    }

    try {
        const result = await apiRequest('/reset-password', {
            method: 'POST',
            body: JSON.stringify({ email, newPassword })
        });
        
        if (result.success) {
            showFloatingMessage(translations['password-changed-success'] || "تم تغيير كلمة المرور بنجاح.", true);
            // Clear all forms
            elements.forgotPasswordEmail.value = '';
            elements.forgotPasswordName.value = '';
            elements.newPassword.value = '';
            elements.confirmNewPassword.value = '';
            // Reset to first step
            elements.verifyIdentityStep.style.display = 'block';
            elements.resetPasswordStep.style.display = 'none';
            // Go back to login page
            setTimeout(() => {
                showPage('login-page');
            }, 2000);
        } else {
            showFloatingMessage(translations['password-change-failed'] || "فشل في تغيير كلمة المرور.", false);
        }
    } catch (error) {
        showFloatingMessage(`فشل في تغيير كلمة المرور: ${error.message}`, false);
    }
}

function handleLogout() {
    state.webUserId = null;
    state.isGuest = false;
    localStorage.removeItem('webUserId');
    elements.logoutButton.style.display = 'none';
    showPage('login-page');
}

// Guest login button event listener
if (elements.guestLoginButton) {
    elements.guestLoginButton.addEventListener("click", () => {
        showPage('login-page');
        // Make sure we're in login mode (not register mode)
        setTimeout(() => {
            if (elements.loginButton && elements.registerButton) {
                elements.loginButton.style.display = 'block';
                elements.registerButton.style.display = 'none';
            }
        }, 100);
    });
}

// Main login button event listener (for guests)
if (elements.mainLoginButton) {
    elements.mainLoginButton.addEventListener("click", () => {
        showPage('login-page');
        // Make sure we're in login mode (not register mode)
        setTimeout(() => {
            if (elements.loginButton && elements.registerButton) {
                elements.loginButton.style.display = 'block';
                elements.registerButton.style.display = 'none';
            }
        }, 100);
    });
}

// Guest register link event listener
if (elements.guestRegisterLink) {
    elements.guestRegisterLink.addEventListener("click", (e) => {
        e.preventDefault();
        showPage('login-page');
        // Switch to register mode
        setTimeout(() => {
            if (elements.toggleFormLink) {
                elements.toggleFormLink.click();
            }
        }, 100);
    });
}

// Forgot password link event listener
if (elements.forgotPasswordLink) {
    elements.forgotPasswordLink.addEventListener("click", (e) => {
        e.preventDefault();
        showPage('forgot-password-page');
    });
}

// Privacy Policy routing function
function openPrivacyPolicy() {
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    let privacyPolicyUrl;
    
    switch (currentLanguage) {
        case 'en':
            privacyPolicyUrl = 'privacy-policy-en.html';
            break;
        case 'fr':
            privacyPolicyUrl = 'privacy-policy-fr.html';
            break;
        default:
            privacyPolicyUrl = 'privacy-policy.html';
            break;
    }
    
    window.open(privacyPolicyUrl, '_blank');
}

// Privacy Policy link event listeners
if (elements.privacyPolicyLinkLogin) {
    elements.privacyPolicyLinkLogin.addEventListener("click", (e) => {
        e.preventDefault();
        openPrivacyPolicy();
    });
}

if (elements.privacyPolicyLinkForgot) {
    elements.privacyPolicyLinkForgot.addEventListener("click", (e) => {
        e.preventDefault();
        openPrivacyPolicy();
    });
}

if (elements.privacyPolicyLinkMenu) {
    elements.privacyPolicyLinkMenu.addEventListener("click", (e) => {
        e.preventDefault();
        openPrivacyPolicy();
    });
}

// Go to main from login button event listener
if (elements.goToMainFromLoginButton) {
    elements.goToMainFromLoginButton.addEventListener("click", (e) => {
        e.preventDefault();
        // Set user as guest and show main page
        state.isGuest = true;
        updateUIForUserStatus();
        showPage('main-menu-page');
    });
}

// Verify identity button event listener
if (elements.verifyIdentityButton) {
    elements.verifyIdentityButton.addEventListener("click", handleVerifyIdentity);
}

// Reset password button event listener
if (elements.resetPasswordButton) {
    elements.resetPasswordButton.addEventListener("click", handleResetPassword);
}

// Back to login link event listener
if (elements.backToLoginLink) {
    elements.backToLoginLink.addEventListener("click", (e) => {
        e.preventDefault();
        // Reset forms
        elements.forgotPasswordEmail.value = '';
        elements.forgotPasswordName.value = '';
        elements.newPassword.value = '';
        elements.confirmNewPassword.value = '';
        // Reset to first step
        elements.verifyIdentityStep.style.display = 'block';
        elements.resetPasswordStep.style.display = 'none';
        showPage('login-page');
    });
}

elements.toggleFormLink.addEventListener('click', (e) => {
    e.preventDefault();
    const isLoginView = elements.loginButton.style.display !== 'none';
    if (isLoginView) {
        document.getElementById('login-title').textContent = 'إنشاء حساب جديد';
        document.getElementById('fullName-group').style.display = 'block';
        document.getElementById('confirmPassword-group').style.display = 'block';
        elements.loginButton.style.display = 'none';
        elements.registerButton.style.display = 'block';
        e.target.textContent = 'لديك حساب بالفعل؟ سجل الدخول';
    } else {
        document.getElementById('login-title').textContent = 'تسجيل الدخول';
        document.getElementById('fullName-group').style.display = 'none';
        document.getElementById('confirmPassword-group').style.display = 'none';
        elements.loginButton.style.display = 'block';
        elements.registerButton.style.display = 'none';
        e.target.textContent = 'ليس لديك حساب؟ أنشئ واحداً';
    }
});

elements.loginButton.addEventListener('click', handleLogin);
elements.registerButton.addEventListener('click', handleRegister);
elements.logoutButton.addEventListener('click', handleLogout);

const loginFields = [elements.loginUsernameInput, elements.loginPasswordInput, elements.registerFullNameInput, document.getElementById('register-confirmPassword')];
loginFields.forEach(field => {
    field.addEventListener('keypress', (event) => {
        if (event.key === 'Enter') {
            event.preventDefault();
            if (elements.loginButton.style.display !== 'none') {
                handleLogin();
            } else if (elements.registerButton.style.display !== 'none') {
                handleRegister();
            }
        }
    });
});

// --- NEW: Go to page event listeners ---
elements.goToPageConfirmBtn.addEventListener('click', handleGoToPage);
elements.goToPageCancelBtn.addEventListener('click', hideGoToPageModal);
elements.goToPageInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        handleGoToPage();
    }
});

// --- NEW: Go to Surah Modal Listeners ---
elements.goToSurahInput.addEventListener('input', (e) => {
    const searchTerm = e.target.value.trim();
    const normalizedSearchTerm = normalizeArabicText(searchTerm);
    const filteredSurahs = state.surahs.filter(surah => {
        const normalizedSurahName = normalizeArabicText(surah.surah_name);
        return normalizedSurahName.includes(normalizedSearchTerm) || String(surah.surah_order).includes(normalizedSearchTerm);
    });
    populateSurahList(filteredSurahs);
});

elements.goToSurahList.addEventListener('click', (e) => {
    const li = e.target.closest('li');
    if (li && li.dataset.startPage) {
        const pageNumber = parseInt(li.dataset.startPage, 10);
        if (!isNaN(pageNumber)) {
            state.currentQuranPage = pageNumber;
            renderQuranPage(state.currentQuranPage);
            hideGoToSurahModal();
        }
    }
});

elements.goToSurahCancelBtn.addEventListener('click', hideGoToSurahModal);
elements.goToSurahOverlay.addEventListener('click', (e) => {
    if (e.target === elements.goToSurahOverlay) {
        hideGoToSurahModal();
    }
});
// --- NEW: Go to Juz Modal Listeners ---
elements.goToJuzList.addEventListener('click', (e) => {
    const li = e.target.closest('li');
    if (li && li.dataset.startPage) {
        const pageNumber = parseInt(li.dataset.startPage, 10);
        if (!isNaN(pageNumber)) {
            state.currentQuranPage = pageNumber;
            renderQuranPage(state.currentQuranPage);
            hideGoToJuzModal();
        }
    }
});

elements.goToJuzCancelBtn.addEventListener('click', hideGoToJuzModal);

elements.goToJuzOverlay.addEventListener('click', (e) => {
    if (e.target === elements.goToJuzOverlay) {
        hideGoToJuzModal();
    }
});

// --- START: Hadith Logic ---
async function initializeHadithPage() {
    showPage('hadith-page');
    elements.hadithPage.innerHTML = `<p style="text-align:center;">جاري تحميل كتب الحديث...</p>`;

    try {
        // Clear any cached hadith data to ensure fresh data
        localStorage.removeItem('hadithBooks');
        state.hadithsInCurrentBook = null;
        state.currentHadithBook = null;
        
        const books = await apiRequest(`/hadith/books?t=${Date.now()}`);
        console.log('Loaded hadith books:', books);
            state.hadithBooks = books;
            localStorage.setItem('hadithBooks', JSON.stringify(books));
            renderHadithBookSelection();
    } catch (error) {
        elements.hadithPage.innerHTML = `<p style="text-align:center; color:red;">فشل تحميل كتب الحديث.</p>`;
        console.error("Failed to load hadith books:", error);
    }
}

function renderHadithBookSelection() {
    const buttonsHTML = state.hadithBooks.map(book =>
        `<button class="menu-button hadith-book-button" data-book-name="${book}">${Hadith_Books_Ar[book]}</button>`
    ).join('');

    elements.hadithPage.innerHTML = `
        <div class="page-header">
            <h3 style="text-align:center; color:green;">✅ نعرض الأحاديث الصحيحة فقط</h3>
        </div>
        <h3 style="text-align:center; color:purple;font-weight:bold; margin-bottom:1rem;">اختر كتابًا لعرض الأحاديث:</h3>
        <div class="menu-buttons">${buttonsHTML}</div>
        <button id="back-to-menu-from-hadith" class="back-button" aria-label="${translations['back'] || 'العودة'}">➡️</button>
    `;
}

async function fetchAndDisplayHadiths(bookName) {
    console.log(`Fetching hadiths for book: ${bookName}`);
    elements.hadithPage.innerHTML = `<p style="text-align:center;">جاري تحميل الأحاديث من ${Hadith_Books_Ar[bookName]}...</p>`;
    try {
        // Clear any previous hadith data
        state.hadithsInCurrentBook = null;
        state.currentHadithBook = null;
        state.currentHadithIndex = 0;
        
        const url = `/hadith/search?book=${encodeURIComponent(bookName)}&t=${Date.now()}`;
        console.log(`Making request to: ${url}`);
        const response = await apiRequest(url);
        console.log(`Received response for book ${bookName}:`, response);
        // Handle new API response format that returns {results, total, has_more}
        const hadiths = response.results || response;
        if (hadiths && hadiths.length > 0) {
            console.log(`First hadith loaded successfully`);
        }
        state.hadithsInCurrentBook = hadiths;
        state.currentHadithBook = bookName;
        state.currentHadithIndex = 0;
        renderSingleHadith();
    } catch (error) {
        console.error(`Error fetching hadiths for book ${bookName}:`, error);
        elements.hadithPage.innerHTML = `<p style="text-align:center; color:red;">فشل تحميل الأحاديث.</p>`;
    }
}

function renderSingleHadith() {
    window.scrollTo(0, 0);
    const hadith = state.hadithsInCurrentBook[state.currentHadithIndex];
    if (!hadith) {
        renderHadithBookSelection();
        showFloatingMessage(translations['no-hadiths-in-book'] || "لا توجد أحاديث في هذا الكتاب.", false);
        return;
    }

    let explanationHTML = '';
    if (hadith.hadith_explaination && hadith.hadith_explaination.trim()) {
        const explanationTitle = translations['hadith-explanation'] || 'شرح الحديث:';
        explanationHTML = `
            <div class="hadith-explanation">
                <h4>${explanationTitle}</h4>
                <p>${hadith.hadith_explaination}</p>
            </div>
        `;
    }

    let infoTagsHTML = '';    
    if (hadith.hadith_heading_ar) infoTagsHTML += `<span class="hadith-info-tag">الموضوع: ${hadith.hadith_heading_ar}</span>`;
    if (hadith.hadith_chapter_ar) infoTagsHTML += `<span class="hadith-info-tag">الفصل: ${hadith.hadith_chapter_ar}</span>`;
    //if (hadith.hadith_number) infoTagsHTML += `<span class="hadith-info-tag">رقم الحديث: ${hadith.hadith_number}</span>`;-->
    //if (hadith.hadith_status_ar) infoTagsHTML += `<span class="hadith-info-tag">درجة الحديث: ${hadith.hadith_status_ar}</span>`;


    elements.hadithPage.innerHTML = `
        <div class="page-header">
            <h2>${Hadith_Books_Ar[state.currentHadithBook]}</h2>
            <div class="page-header-actions">
                <button id="share-hadith-btn" class="share-button" title="${translations['share-hadith'] || 'مشاركة الحديث'}">🔗</button>
                <button id="hadith-search-icon" class="search-button" aria-label="${translations['search-in-hadith'] || 'بحث في الحديث'}">🔍</button>
            </div>
        </div>
        <div class="hadith-display-frame">
            <p class="hadith-text">${hadith.hadith_text_ar}</p>
        </div>
        <div class="hadith-info-container">${infoTagsHTML}</div>
        <div class="hadith-nav">
            <button id="hadith-prev-btn" class="menu-button secondary" ${state.currentHadithIndex === 0 ? 'disabled' : ''}>➡️ الحديث السابق</button>
            <button id="hadith-next-btn" class="menu-button" ${state.currentHadithIndex >= state.hadithsInCurrentBook.length - 1 ? 'disabled' : ''}>${translations['next-hadith'] || 'الحديث التالي'} ⬅️</button>
        </div>
        ${explanationHTML}
        <button id="back-to-hadith-books" class="back-button" aria-label="${translations['back'] || 'العودة'}">➡️</button>
        
        <div id="hadith-search-panel">
            <div class="hadith-search-modal">
                <h3>البحث في ${Hadith_Books_Ar[state.currentHadithBook]}</h3>
                <div class="hadith-filter-group">
                    <label for="hadith-chapter-filter">الفصل (اختياري):</label>
                    <select id="hadith-chapter-filter"><option value="">كل الفصول</option></select>
                </div>
                <div class="hadith-filter-group">
                    <label for="hadith-term-filter">كلمة البحث (اختياري):</label>
                    <input type="text" id="hadith-term-filter" placeholder="${translations['search-hadith-placeholder'] || 'ابحث في نص الحديث...'}">
                </div>
                <div class="menu-buttons" style="margin-top: 1.5rem; flex-direction: row;">
                    <button id="execute-hadith-search-btn" class="menu-button">ابحث</button>
                    <button id="close-hadith-search-btn" class="menu-button secondary">إغلاق</button>
                </div>
                <div id="hadith-search-results-container">
                    <p id="hadith-search-results-count" style="display: none;"></p>
                    <ul id="hadith-search-results-list"></ul>
                </div>
            </div>
        </div>
    `;
    // --- START: Share Button Event Listener for Hadith ---
    document.getElementById('share-hadith-btn').addEventListener('click', () => {
        // نقوم بالترميز القياسي ثم نضيف ترميزاً يدوياً لعلامة التنصيص
        let bookNameEncoded = encodeURIComponent( Hadith_Books_En[ state.currentHadithBook]).replace(/'/g, "%27");
        bookNameEncoded = bookNameEncoded.replace(/ /g, "%20");
        const url = `https://qurani.info/${bookNameEncoded}/${hadith.hadith_number}`;

        console.log("Generated Share URL:", url); // للتحقق

        const title = `حديث شريف من ${Hadith_Books_Ar[state.currentHadithBook]} (عبر تطبيق قرآني ✨)`;
        const text = `أشارككم هذا الحديث من ${Hadith_Books_Ar[state.currentHadithBook]}:\n"${hadith.hadith_text_ar.substring(0, 120)}..."`;
        showShareModal(url, title, text);
    });
    // --- END: Share Button Event Listener for Hadith ---
    attachHadithSwipeHandlers(elements.hadithPage);
}

function handleHadithNavigation(direction) {
    if (direction === 'next' && state.currentHadithIndex < state.hadithsInCurrentBook.length - 1) {
        state.currentHadithIndex++;
        renderSingleHadith();
    } else if (direction === 'prev' && state.currentHadithIndex > 0) {
        state.currentHadithIndex--;
        renderSingleHadith();
    }
}

async function showHadithSearchPanel() {
    const panel = document.getElementById('hadith-search-panel');
    if (panel) {
        panel.style.display = 'block';
        const chapterSelect = document.getElementById('hadith-chapter-filter');
        chapterSelect.innerHTML = '<option value="">جاري تحميل الفصول...</option>';
        try {
            const chapters = await apiRequest(`/hadith/chapters?book=${encodeURIComponent(state.currentHadithBook)}`);
            chapterSelect.innerHTML = '<option value="">كل الفصول</option>';
            chapters.forEach(chapter => {
                const option = document.createElement('option');
                option.value = chapter;
                option.textContent = chapter;
                chapterSelect.appendChild(option);
            });
        } catch (error) {
            chapterSelect.innerHTML = '<option value="">فشل تحميل الفصول</option>';
        }
    }
}

function hideHadithSearchPanel() {
    const panel = document.getElementById('hadith-search-panel');
    if (panel) panel.style.display = 'none';
}

async function performHadithSearch() {
    const chapter = document.getElementById('hadith-chapter-filter').value;
    const term = document.getElementById('hadith-term-filter').value;
    const resultsList = document.getElementById('hadith-search-results-list');
    const resultsCount = document.getElementById('hadith-search-results-count');

    resultsList.innerHTML = '<li>جاري البحث...</li>';
    resultsCount.style.display = 'none';

    try {
        const response = await apiRequest(`/hadith/search?book=${encodeURIComponent(state.currentHadithBook)}&chapter=${encodeURIComponent(chapter)}&term=${encodeURIComponent(term)}`);
        // Handle new API response format that returns {results, total, has_more}
        const results = response.results || response;
        renderHadithSearchResults(results);
    } catch (error) {
        resultsList.innerHTML = '<li>فشل البحث.</li>';
    }
}

function renderHadithSearchResults(results) {
    const resultsList = document.getElementById('hadith-search-results-list');
    const resultsCount = document.getElementById('hadith-search-results-count');
    resultsList.innerHTML = '';

    resultsCount.textContent = `تم العثور على ${results.length} نتيجة.`;
    resultsCount.style.display = 'block';

    if (results.length === 0) {
        resultsList.innerHTML = '<li>لم يتم العثور على نتائج.</li>';
        return;
    }

    results.forEach((hadith, index) => {
        const li = document.createElement('li');
        li.className = 'hadith-search-result-item';
        li.dataset.hadithIndex = state.hadithsInCurrentBook.findIndex(h => h.hadith_id === hadith.hadith_id);
        li.innerHTML = `<p>${hadith.hadith_text_ar.substring(0, 150)}...</p>`;
        resultsList.appendChild(li);
    });
}


elements.goToHadithButton.addEventListener('click', initializeHadithPage);

elements.hadithPage.addEventListener('click', (e) => {
    const buttonTarget = e.target.closest('button');
    const searchResultTarget = e.target.closest('.hadith-search-result-item');

    if (buttonTarget) {
        if (buttonTarget.matches('.hadith-book-button')) {
            console.log('Clicked book button:', buttonTarget.dataset.bookName);
            fetchAndDisplayHadiths(buttonTarget.dataset.bookName);
        } else if (buttonTarget.id === 'back-to-menu-from-hadith') {
            showPage('main-menu-page');
        } else if (buttonTarget.id === 'back-to-hadith-books') {
            renderHadithBookSelection();
        } else if (buttonTarget.id === 'hadith-next-btn') {
            handleHadithNavigation('next');
        } else if (buttonTarget.id === 'hadith-prev-btn') {
            handleHadithNavigation('prev');
        } else if (buttonTarget.id === 'hadith-search-icon') {
            showHadithSearchPanel();
        } else if (buttonTarget.id === 'close-hadith-search-btn') {
            hideHadithSearchPanel();
        } else if (buttonTarget.id === 'execute-hadith-search-btn') {
            performHadithSearch();
        }
    } else if (searchResultTarget) {
        const index = parseInt(searchResultTarget.dataset.hadithIndex, 10);
        if (!isNaN(index) && index >= 0) {
            state.currentHadithIndex = index;
            renderSingleHadith();
            hideHadithSearchPanel();
        }
    }
});

// --- END: Hadith Logic ---
// RECITATION

    elements.recitationSurahSearchInput.addEventListener('input', (e) => {
        const searchTerm = e.target.value.trim();
        const normalizedSearchTerm = normalizeArabicText(searchTerm);
        const filteredSurahs = state.surahs.filter(surah => {
            const normalizedSurahName = normalizeArabicText(surah.surah_name);
            return normalizedSurahName.includes(normalizedSearchTerm);
        });
        elements.recitationSurahListContainer.innerHTML = generateSurahButtonsHTML(filteredSurahs);
    });

    elements.startVerseInput.addEventListener('input', (e) => {
        elements.startVerseSlider.value = e.target.value;
    });

    elements.endVerseInput.addEventListener('input', (e) => {
        elements.endVerseSlider.value = e.target.value;
    });

    elements.startVerseSlider.addEventListener('input', (e) => {
        elements.startVerseInput.value = e.target.value;
        if (parseInt(elements.startVerseInput.value) > parseInt(elements.endVerseInput.value)) {
            elements.endVerseInput.value = e.target.value;
            elements.endVerseSlider.value = e.target.value;
        }
    });

    elements.endVerseSlider.addEventListener('input', (e) => {
        elements.endVerseInput.value = e.target.value;
        if (parseInt(elements.endVerseInput.value) < parseInt(elements.startVerseInput.value)) {
            elements.startVerseInput.value = e.target.value;
            elements.startVerseSlider.value = e.target.value;
        }
    });

    elements.recitationPage.addEventListener('click', (e) => {
        const verseNavBtn = e.target.closest('.verse-nav-btn');
        if (verseNavBtn) {
            const target = verseNavBtn.dataset.target;
            const action = verseNavBtn.dataset.action;
            const input = (target === 'start') ? elements.startVerseInput : elements.endVerseInput;
            const slider = (target === 'start') ? elements.startVerseSlider : elements.endVerseSlider;
            let value = parseInt(input.value, 10);

            if (action === 'plus' && value < parseInt(input.max, 10)) {
                value++;
            } else if (action === 'minus' && value > parseInt(input.min, 10)) {
                value--;
            }
            input.value = value;
            slider.value = value;
            
            if (target === 'start' && value > parseInt(elements.endVerseInput.value, 10)) {
                elements.endVerseInput.value = value;
                elements.endVerseSlider.value = value;
            }
            
            if (target === 'end' && value < parseInt(elements.startVerseInput.value, 10)) {
                elements.startVerseInput.value = value;
                elements.startVerseSlider.value = value;
            }
            return; 
        }

        if (e.target.id === 'record-btn' || e.target.closest('#record-btn')) {
            // إذا كانت النتائج ظاهرة، فالضغط على الزر يعني "إعادة الاختبار"
            // وفي هذه الحالة يجب إعادة تهيئة شاشة الاختبار بالكامل
            if (elements.recitationTestResults.style.display !== 'none') {
                renderRecitationTestPage();
            } else {
                // وإلا، فهو ضغطة عادية لبدء أو إيقاف التسجيل
                toggleRecording();
            }
            return;
        }
        
        // NEW: Playback button click handler
        if (e.target.id === 'play-back-btn') {
            playRecordedAudio();
            return;
        }

        const surahButton = e.target.closest('.surah-button');
        if (surahButton) {
            const surahName = surahButton.dataset.surahName;
            const surahOrder = parseInt(surahButton.dataset.surahOrder, 10);
            updateVerseSelectionPanel(surahName, surahOrder);
            return;
        }

        if (e.target.id === 'start-recitation-btn') {
            const startVerse = parseInt(elements.startVerseInput.value, 10);
            const endVerse = parseInt(elements.endVerseInput.value, 10);

            if (startVerse > endVerse) {
                showFloatingMessage(translations['start-verse-must-be-smaller'] || "آية البداية يجب أن تكون أصغر من أو تساوي آية النهاية.", false);
                return;
            }

            state.recitation.startVerse = startVerse;
            state.recitation.endVerse = endVerse;

            renderRecitationTestPage();
            return;
        }
        
        if (e.target.id === 'back-to-recitation-selection') {
            const isTestPanelVisible = elements.recitationTestPanel.style.display !== 'none';
            const isVerseSelectionVisible = elements.verseSelectionPanel.style.display !== 'none';

            if (isTestPanelVisible) {
                // الحالة 1: نحن في صفحة الاختبار -> نعود لصفحة اختيار الآيات
                elements.recitationTestPanel.style.display = 'none';
                elements.verseSelectionPanel.style.display = 'block';
                // نعيد العنوان الأصلي للصفحة
                const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
                const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
                elements.recitationPage.querySelector('.page-header h2').textContent = translations['recitation-test'] || 'اختبار التسميع';
            } else if (isVerseSelectionVisible) {
                // الحالة 2: نحن في صفحة اختيار الآيات -> نعود لقائمة السور
                renderRecitationPage();
            } else {
                // الحالة 3: نحن في قائمة السور -> نعود للقائمة الرئيسية
                showPage('main-menu-page');
            }
        }
    });


// --- END: Recitation Logic ---

// --- UI Management for User Status ---
function updateUIForUserStatus() {
    const isGuest = state.isGuest;
    const isLoggedIn = state.webUserId || (isTelegram && tg.initData);
    const isTelegramUser = isTelegram && tg.initData;
    
    console.log('Updating UI for user status:', { isGuest, isLoggedIn, webUserId: state.webUserId, isTelegramUser });
    
    // Show/hide guest login invitation (never show for Telegram users)
    if (elements.guestLoginInvitation) {
        elements.guestLoginInvitation.style.display = (isGuest && !isTelegramUser) ? 'block' : 'none';
        console.log('Guest login invitation display:', (isGuest && !isTelegramUser) ? 'block' : 'none');
    }
    
    // Show/hide logout button (only for web users, not Telegram users)
    if (elements.logoutButton) {
        elements.logoutButton.style.display = (state.webUserId && !isTelegramUser) ? 'flex' : 'none';
    }
    
    // Show/hide main login button (for guests, but not Telegram users)
    if (elements.mainLoginButton) {
        elements.mainLoginButton.style.display = (isGuest && !isTelegramUser) ? 'flex' : 'none';
        console.log('Main login button display:', (isGuest && !isTelegramUser) ? 'flex' : 'none');
    }
    
    // Hide guest login button and register link for Telegram users
    if (elements.guestLoginButton) {
        elements.guestLoginButton.style.display = (isGuest && !isTelegramUser) ? 'block' : 'none';
    }
    
    if (elements.guestRegisterLink) {
        elements.guestRegisterLink.style.display = (isGuest && !isTelegramUser) ? 'block' : 'none';
    }
    
    // Hide protected services for guests (but not for Telegram users)
    const protectedServices = document.querySelectorAll('.protected-service');
    console.log('Found protected services:', protectedServices.length);
    protectedServices.forEach(service => {
        if (isGuest && !isTelegramUser) {
            service.style.display = 'none';
            console.log('Hiding protected service:', service.textContent);
        } else {
            service.style.display = 'block';
        }
    });
    
    // Update welcome message
    if (elements.welcomeMessage) {
        if (isGuest && !isTelegramUser) {
            elements.welcomeMessage.textContent = 'مرحباً بك في تطبيق قرآني! 🌟';
        } else if (state.webUserId) {
            elements.welcomeMessage.textContent = `مرحباً ${state.userFullName || 'بك'} في تطبيق قرآني! 🌟`;
        } else if (isTelegramUser) {
            elements.welcomeMessage.textContent = 'مرحباً بك في تطبيق قرآني! 🌟';
        }
    }
}

// --- Main App Initialization ---
async function initializeApp() {
    console.log("✅ App Initialized");
    // Check if Telegram WebApp is available (use the global variable)
    const isTelegramApp = isTelegram;

    if (!isTelegramApp) {
        document.body.classList.add('platform-web');
        const container = document.querySelector('.container');
        if (container) {
            container.classList.add('container-wide');
        }
    } else {
        tg.expand();
        tg.MainButton.hide();
    }

    loadSavedTheme();
    loadSavedLanguage();
    
    // Pre-load surah data
    try {
        const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
        console.log(`🔄 Pre-loading surah data for language: ${currentLanguage}`);
        const surahs = await loadSurahData(currentLanguage);
        if (surahs && surahs.length > 0) {
            state.surahs = surahs;
            console.log(`✅ Pre-loaded ${surahs.length} surahs successfully`);
        } else {
            console.warn('⚠️ No surahs loaded during pre-load');
        }
    } catch (error) {
        console.error('❌ Failed to pre-load surah data:', error);
    }
    
    const savedUserId = localStorage.getItem('webUserId');

    const startApp = async () => {
        try {
            await apiRequest('/health');
            await Promise.all([loadInitialData(), loadSurahOptions()]);
        } catch (error) {
            showFloatingMessage(translations['server-connection-failed'] || "لا يمكن الاتصال بالخادم. يرجى التأكد من أن الخادم يعمل.", false);
            elements.totalScoreMain.textContent = 'خطأ في الاتصال';
            elements.leaderboardList.innerHTML = '<li>خطأ في الاتصال بالخادم</li>';
        }
    };

    if (savedUserId) {
        console.log('Web user found with saved ID:', savedUserId);
        state.webUserId = savedUserId;
        state.isGuest = false;
        showPage('main-menu-page');
        updateUIForUserStatus();
        startApp();
    } else if (isTelegramApp) {
        console.log('Telegram app detected, treating as authenticated user...');
        // Telegram users are treated as authenticated without login
        state.isGuest = false;
        console.log('Telegram app detected, setting as authenticated, state.isGuest:', state.isGuest);
        showPage('main-menu-page');
        updateUIForUserStatus();
        startApp();
    } else {
        // For web users without login, show main menu as guest
        state.isGuest = true;
        showPage('main-menu-page');
        updateUIForUserStatus();
        startApp();
    }
    
    // Initialize password toggle buttons
    initializePasswordToggleButtons();
}

// --- START: Share Modal Event Listeners ---
if (elements.shareModalOverlay) {
    elements.closeShareModalBtn.addEventListener('click', () => {
        elements.shareModalOverlay.style.display = 'none';
        document.body.classList.remove('modal-open');
    });

    elements.shareModalOverlay.addEventListener('click', (e) => {
        if (e.target === elements.shareModalOverlay) {
            elements.shareModalOverlay.style.display = 'none';
            document.body.classList.remove('modal-open');
        }
    });

    elements.copyShareUrlBtn.addEventListener('click', () => {
        elements.shareUrlInput.select();
        try {
            navigator.clipboard.writeText(elements.shareUrlInput.value).then(() => {
                showFloatingMessage('تم نسخ الرابط بنجاح!', true);
            }).catch(() => {
                // Fallback for older browsers
                document.execCommand('copy');
                showFloatingMessage('تم نسخ الرابط بنجاح!', true);
            });
        } catch (err) {
            showFloatingMessage('فشل نسخ الرابط.', false);
            console.error('Could not copy text: ', err);
        }
    });
}
// --- END: Share Modal Event Listeners ---

// Surah name mapping from Latin to Arabic
const surahNameMapping = {
    "Al-Fatiha": "سُورَةُ ٱلْفَاتِحَةِ",
    "Al-Baqara": "سُورَةُ البَقَرَةِ",
    "Aal Imran": "سُورَةُ آلِ عِمۡرَانَ",
    "An-Nisa": "سُورَةُ النِّسَاءِ",
    "Al-Ma'idah": "سُورَةُ المَائـِدَةِ",
    "Al-An'am": "سُورَةُ الأَنۡعَامِ",
    "Al-A'raf": "سُورَةُ الأَعۡرَافِ",
    "Al-Anfal": "سُورَةُ الأَنفَالِ",
    "At-Tawbah": "سُورَةُ التَّوۡبَةِ",
    "Yunus": "سُورَةُ يُونُسَ",
    "Hud": "سُورَةُ هُودٍ",
    "Yusuf": "سُورَةُ يُوسُفَ",
    "Ar-Ra'd": "سُورَةُ الرَّعۡدِ",
    "Ibrahim": "سُورَةُ إِبۡرَٰهِيمَ",
    "Al-Hijr": "سُورَةُ الحِجۡرِ",
    "An-Nahl": "سُورَةُ النَّحۡلِ",
    "Al-Isra": "سُورَةُ الإِسۡرَاءِ",
    "Al-Kahf": "سُورَةُ الكَهۡفِ",
    "Maryam": "سُورَةُ مَرۡيَمَ",
    "Taha": "سُورَةُ طه",
    "Al-Anbiya": "سُورَةُ الأَنبِيَاءِ",
    "Al-Hajj": "سُورَةُ الحَجِّ",
    "Al-Mu'minun": "سُورَةُ المُؤۡمِنُونَ",
    "An-Nur": "سُورَةُ النُّورِ",
    "Al-Furqan": "سُورَةُ الفُرۡقَانِ",
    "Ash-Shu'ara": "سُورَةُ الشُّعَرَاءِ",
    "An-Naml": "سُورَةُ النَّمۡلِ",
    "Al-Qasas": "سُورَةُ القَصَصِ",
    "Al-Ankabut": "سُورَةُ العَنكَبُوتِ",
    "Ar-Rum": "سُورَةُ الرُّومِ",
    "Luqman": "سُورَةُ لُقۡمَانَ",
    "As-Sajdah": "سُورَةُ السَّجۡدَةِ",
    "Al-Ahzab": "سُورَةُ الأَحۡزَابِ",
    "Saba": "سُورَةُ سَبَإٍ",
    "Fatir": "سُورَةُ فَاطِرٍ",
    "Ya-Sin": "سُورَةُ يس",
    "As-Saffat": "سُورَةُ الصَّافَّاتِ",
    "Sad": "سُورَةُ ص",
    "Az-Zumar": "سُورَةُ الزُّمَرِ",
    "Ghafir": "سُورَةُ غَافِرٍ",
    "Fussilat": "سُورَةُ فُصِّلَتۡ",
    "Ash-Shura": "سُورَةُ الشُّورىٰ",
    "Az-Zukhruf": "سُورَةُ الزُّخۡرُفِ",
    "Ad-Dukhan": "سُورَةُ الدُّخَانِ",
    "Al-Jathiyah": "سُورَةُ الجَاثِيَةِ",
    "Al-Ahqaf": "سُورَةُ الأَحۡقَافِ",
    "Muhammad": "سُورَةُ مُحَمَّدٍ",
    "Al-Fath": "سُورَةُ الفَتۡحِ",
    "Al-Hujurat": "سُورَةُ الحُجُرَاتِ",
    "Qaf": "سُورَةُ ق",
    "Adh-Dhariyat": "سُورَةُ الذَّارِيَاتِ",
    "At-Tur": "سُورَةُ الطُّورِ",
    "An-Najm": "سُورَةُ النَّجۡمِ",
    "Al-Qamar": "سُورَةُ القَمَرِ",
    "Ar-Rahman": "سُورَةُ الرَّحۡمَٰنِ",
    "Al-Waqi'ah": "سُورَةُ الوَاقِعَةِ",
    "Al-Hadid": "سُورَةُ الحَدِيدِ",
    "Al-Mujadila": "سُورَةُ المُجَادِلَةِ",
    "Al-Hashr": "سُورَةُ الحَشۡرِ",
    "Al-Mumtahanah": "سُورَةُ المُمۡتَحَنَةِ",
    "As-Saff": "سُورَةُ الصَّفِّ",
    "Al-Jumu'ah": "سُورَةُ الجُمُعَةِ",
    "Al-Munafiqun": "سُورَةُ المُنَافِقُونَ",
    "At-Taghabun": "سُورَةُ التَّغَابُنِ",
    "At-Talaq": "سُورَةُ الطَّلَاقِ",
    "At-Tahrim": "سُورَةُ التَّحۡرِيمِ",
    "Al-Mulk": "سُورَةُ المُلۡكِ",
    "Al-Qalam": "سُورَةُ القَلَمِ",
    "Al-Haqqah": "سُورَةُ الحَاقَّةِ",
    "Al-Ma'arij": "سُورَةُ المَعَارِجِ",
    "Nuh": "سُورَةُ نُوحٍ",
    "Al-Jinn": "سُورَةُ الجِنِّ",
    "Al-Muzzammil": "سُورَةُ المُزَّمِّلِ",
    "Al-Muddaththir": "سُورَةُ المُدَّثِّرِ",
    "Al-Qiyamah": "سُورَةُ القِيَامَةِ",
    "Al-Insan": "سُورَةُ الإِنسَانِ",
    "Al-Mursalat": "سُورَةُ المُرۡسَلَاتِ",
    "An-Naba": "سُورَةُ النَّبَإِ",
    "An-Nazi'at": "سُورَةُ النَّازِعَاتِ",
    "Abasa": "سُورَةُ عَبَسَ",
    "At-Takwir": "سُورَةُ التَّكۡوِيرِ",
    "Al-Infitar": "سُورَةُ الانفِطَارِ",
    "Al-Mutaffifin": "سُورَةُ المُطَفِّفِينَ",
    "Al-Inshiqaq": "سُورَةُ الانشِقَاقِ",
    "Al-Buruj": "سُورَةُ البُرُوجِ",
    "At-Tariq": "سُورَةُ الطَّارِقِ",
    "Al-A'la": "سُورَةُ الأَعۡلَىٰ",
    "Al-Ghashiyah": "سُورَةُ الغَاشِيَةِ",
    "Al-Fajr": "سُورَةُ الفَجۡرِ",
    "Al-Balad": "سُورَةُ البَلَدِ",
    "Ash-Shams": "سُورَةُ الشَّمۡسِ",
    "Al-Layl": "سُورَةُ اللَّيۡلِ",
    "Ad-Duha": "سُورَةُ الضُّحَىٰ",
    "Ash-Sharh": "سُورَةُ الشَّرۡحِ",
    "At-Tin": "سُورَةُ التِّينِ",
    "Al-Alaq": "سُورَةُ العَلَقِ",
    "Al-Qadr": "سُورَةُ القَدۡرِ",
    "Al-Bayyinah": "سُورَةُ البَيِّنَةِ",
    "Az-Zalzalah": "سُورَةُ الزَّلۡزَلَةِ",
    "Al-Adiyat": "سُورَةُ العَادِيَاتِ",
    "Al-Qari'ah": "سُورَةُ القَارِعَةِ",
    "At-Takathur": "سُورَةُ التَّكَاثُرِ",
    "Al-Asr": "سُورَةُ العَصۡرِ",
    "Al-Humazah": "سُورَةُ الهُمَزَةِ",
    "Al-Fil": "سُورَةُ الفِيلِ",
    "Quraysh": "سُورَةُ قُرَيۡشٍ",
    "Al-Ma'un": "سُورَةُ المَاعُونِ",
    "Al-Kawthar": "سُورَةُ الكَوۡثَرِ",
    "Al-Kafirun": "سُورَةُ الكَافِرُونَ",
    "An-Nasr": "سُورَةُ النَّصۡرِ",
    "Al-Masad": "سُورَةُ المَسَدِ",
    "Al-Ikhlas": "سُورَةُ الإِخۡلَاصِ",
    "Al-Falaq": "سُورَةُ الفَلَقِ",
    "An-Nas": "سُورَةُ النَّاسِ"
};

// Function to get Arabic surah name from Latin name
function getArabicSurahName(latinName) {
    return surahNameMapping[latinName] || latinName;
}

// Function to translate Juz names
function translateJuzName(juzNumber) {
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
    
    if (juzNumber === 29) {
        return `${translations['juz-tabarak'] || 'جزء تبارك'} ${juzNumber}`;
    } else if (juzNumber === 30) {
        return `${translations['juz-am'] || 'جزء عم'} ${juzNumber}`;
    } else {
        return `${translations['juz'] || 'الجزء'} ${juzNumber}`;
    }
}

// Function to update Juz names translation
function updateJuzNamesTranslation() {
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
    
    // تحديث أسماء الأجزاء في قائمة الاختبار
    document.querySelectorAll('[data-translate="juz"]').forEach(element => {
        const number = element.getAttribute('data-number');
        if (number) {
            element.innerHTML = `${translations['juz'] || 'الجزء'} ${number}`;
        }
    });
    
    // تحديث الجزء 29 (تبارك)
    document.querySelectorAll('[data-translate="juz-tabarak"]').forEach(element => {
        const number = element.getAttribute('data-number');
        if (number) {
            element.innerHTML = `${translations['juz-tabarak'] || 'جزء تبارك'} ${number}`;
        }
    });
    
    // تحديث الجزء 30 (عم)
    document.querySelectorAll('[data-translate="juz-am"]').forEach(element => {
        const number = element.getAttribute('data-number');
        if (number) {
            element.innerHTML = `${translations['juz-am'] || 'جزء عم'} ${number}`;
        }
    });
}

// Function to toggle password visibility
function togglePasswordVisibility(button) {
    const targetId = button.getAttribute('data-password-target');
    const passwordInput = document.getElementById(targetId);
    const currentLanguage = localStorage.getItem('appLanguage') || 'ar';
    const translations = (window.translations && window.translations[currentLanguage]) || (window.translations && window.translations.ar) || {};
    
    if (passwordInput.type === 'password') {
        passwordInput.type = 'text';
        button.textContent = '🙈';
        button.title = translations['hide-password'] || 'إخفاء كلمة المرور';
    } else {
        passwordInput.type = 'password';
        button.textContent = '👁️';
        button.title = translations['show-password'] || 'إظهار كلمة المرور';
    }
}

// Initialize password toggle buttons
function initializePasswordToggleButtons() {
    document.querySelectorAll('.password-toggle-btn').forEach(button => {
        button.addEventListener('click', () => togglePasswordVisibility(button));
    });
}

// Wait for translations to be loaded before initializing
async function waitForTranslations() {
    let retries = 0;
    while (!window.translations && retries < 50) {
        await new Promise(resolve => setTimeout(resolve, 100));
        retries++;
    }
    
    if (!window.translations) {
        console.error('❌ Translations not loaded after 5 seconds');
    } else {
        console.log('✅ Translations loaded successfully');
    }
    
    await initializeApp();
}

// دالة ترجمة أسماء القراء
function translateReciterName(arabicName, languageCode = 'ar') {
    if (!window.translations || !window.translations.reciters) {
        return arabicName;
    }
    
    const reciterTranslations = window.translations.reciters[languageCode];
    return reciterTranslations && reciterTranslations[arabicName] ? reciterTranslations[arabicName] : arabicName;
}

// دالة ترجمة أسماء كتب التفسير
function translateTafsirBookName(arabicName, languageCode = 'ar') {
    if (!window.translations || !window.translations.tafsirBooks) {
        return arabicName;
    }
    
    const tafsirTranslations = window.translations.tafsirBooks[languageCode];
    return tafsirTranslations && tafsirTranslations[arabicName] ? tafsirTranslations[arabicName] : arabicName;
}

waitForTranslations();

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker.js').then(registration => {
      console.log('ServiceWorker registration successful with scope: ', registration.scope);
    }, err => {
      console.log('ServiceWorker registration failed: ', err);
    });
  });
}