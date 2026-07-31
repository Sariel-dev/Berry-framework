/* ==========================================================================
   BERRY PROGRESS BAR ENGINE
   ========================================================================== */
let progressBarInterval = null;

function startBerryProgressBar(duration, label) {
    const container = document.getElementById('berry-progressbar-container');
    const labelSpan = document.getElementById('progressbar-label');
    const percentageSpan = document.getElementById('progressbar-percentage');
    const fillBar = document.getElementById('progressbar-fill');

    if (!container || !fillBar) return;

    if (progressBarInterval) clearInterval(progressBarInterval);

    labelSpan.innerText = label || "Action en cours...";
    percentageSpan.innerText = "0%";
    fillBar.style.width = "0%";

    container.classList.remove('hidden');

    const startTime = Date.now();
    const totalDuration = duration || 3000;

    progressBarInterval = setInterval(() => {
        const elapsed = Date.now() - startTime;
        const progress = Math.min(100, Math.floor((elapsed / totalDuration) * 100));

        fillBar.style.width = `${progress}%`;
        percentageSpan.innerText = `${progress}%`;

        if (progress >= 100) {
            clearInterval(progressBarInterval);
            progressBarInterval = null;
            setTimeout(() => {
                container.classList.add('hidden');
            }, 200);
        }
    }, 50);
}

function stopBerryProgressBar() {
    if (progressBarInterval) {
        clearInterval(progressBarInterval);
        progressBarInterval = null;
    }
    const container = document.getElementById('berry-progressbar-container');
    if (container) container.classList.add('hidden');
}

/* ==========================================================================
   BERRY NOTIFICATION ENGINE
   ========================================================================== */
let notificationIdCounter = 0;

function addBerryNotification(data) {
    const container = document.getElementById('berry-notifications-container');
    if (!container) return;

    notificationIdCounter++;
    const id = `berry-notif-${notificationIdCounter}`;

    const titleText = data.title || (data.variant ? data.variant.toUpperCase() : 'NOTIFICATION');
    const subtitleText = data.subtitle || '';
    const messageText = data.message || data.content || data.description || '';
    const duration = data.duration || 5000;
    const variant = (data.variant || data.type || 'info').toLowerCase();

    const card = document.createElement('div');
    card.id = id;
    card.className = `berry-notification variant-${variant}`;

    let html = `
        <div class="berry-notification-content-wrapper">
            <div class="berry-notification-header">
                <span class="berry-notification-title">${escapeHtml(titleText)}</span>
                ${subtitleText ? `<span class="berry-notification-subtitle">${escapeHtml(subtitleText)}</span>` : ''}
            </div>
            ${messageText ? `<div class="berry-notification-message">${escapeHtml(messageText)}</div>` : ''}
        </div>
        <div class="berry-notification-progress"></div>
    `;

    card.innerHTML = html;
    container.appendChild(card);

    const progressBar = card.querySelector('.berry-notification-progress');
    if (progressBar) {
        progressBar.style.transition = `width ${duration}ms linear`;
        setTimeout(() => {
            progressBar.style.width = '0%';
        }, 10);
    }

    setTimeout(() => {
        card.classList.add('exiting');
        setTimeout(() => {
            card.remove();
        }, 300);
    }, duration);
}

function escapeHtml(text) {
    if (!text) return '';
    return String(text)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

/* ==========================================================================
   F1 MENU MASTER ROUTER ENGINE
   ========================================================================== */
let isMenuOpen = false;
let currentItems = [];
let currentIndex = 0;

window.addEventListener('message', function (event) {
    const data = event.data;
    if (!data) return;

    // Berry Notifications
    if (data.action === 'notify' || data.action === 'addNotification' || data.action === 'berry_notify') {
        addBerryNotification(data);
    }

    // Berry Progress Bar
    if (data.action === 'startProgressBar' || data.action === 'progress') {
        startBerryProgressBar(data.duration, data.label);
    } else if (data.action === 'stopProgressBar') {
        stopBerryProgressBar();
    }

    // F1 Menu
    if (data.action === 'open') {
        openMenu(data.title, data.subtitle, data.items);
    } else if (data.action === 'close') {
        closeMenu();
    } else if (data.action === 'updateIndex') {
        setIndex(data.index);
    }
});

function openMenu(title, subtitle, items) {
    isMenuOpen = true;
    currentItems = items || [];
    currentIndex = 0;

    document.getElementById('menu-title').innerText = title || 'BERRY';
    document.getElementById('menu-subtitle').innerText = subtitle || 'Actions';
    document.getElementById('f1-container').classList.remove('hidden');

    renderItems();
}

function closeMenu() {
    isMenuOpen = false;
    document.getElementById('f1-container').classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/closeMenu`, { method: 'POST', body: JSON.stringify({}) });
}

function renderItems() {
    const list = document.getElementById('menu-items-list');
    list.innerHTML = '';

    document.getElementById('menu-counter').innerText = `${currentItems.length > 0 ? currentIndex + 1 : 0}/${currentItems.length}`;

    currentItems.forEach((item, idx) => {
        const div = document.createElement('div');
        div.className = `menu-item ${idx === currentIndex ? 'active' : ''}`;
        
        const labelSpan = document.createElement('span');
        labelSpan.innerText = item.label;
        div.appendChild(labelSpan);

        if (item.value !== undefined) {
            const valSpan = document.className = 'menu-item-value';
            valSpan.innerText = item.value;
            div.appendChild(valSpan);
        }

        div.addEventListener('click', () => {
            selectIndex(idx);
        });

        list.appendChild(div);
    });
}

function setIndex(index) {
    if (currentItems.length === 0) return;
    currentIndex = index;
    if (currentIndex < 0) currentIndex = currentItems.length - 1;
    if (currentIndex >= currentItems.length) currentIndex = 0;
    renderItems();
}

function selectIndex(index) {
    currentIndex = index;
    renderItems();
    fetch(`https://${GetParentResourceName()}/selectItem`, {
        method: 'POST',
        body: JSON.stringify({ index: currentIndex })
    });
}

document.addEventListener('keydown', function (e) {
    if (!isMenuOpen) return;

    if (e.key === 'ArrowDown' || e.key === 's' || e.key === 'S') {
        setIndex(currentIndex + 1);
        fetch(`https://${GetParentResourceName()}/playSound`, { method: 'POST', body: JSON.stringify({ name: 'NAV_UP_DOWN' }) });
    } else if (e.key === 'ArrowUp' || e.key === 'z' || e.key === 'Z') {
        setIndex(currentIndex - 1);
        fetch(`https://${GetParentResourceName()}/playSound`, { method: 'POST', body: JSON.stringify({ name: 'NAV_UP_DOWN' }) });
    } else if (e.key === 'Enter') {
        selectIndex(currentIndex);
    } else if (e.key === 'Backspace' || e.key === 'Escape' || e.key === 'F1') {
        fetch(`https://${GetParentResourceName()}/backMenu`, { method: 'POST', body: JSON.stringify({}) });
    }
});
