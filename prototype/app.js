(() => {
  const $ = (id) => document.getElementById(id);
  const phone = $('phone'), board = $('board'), composer = $('composer');
  const input = $('composerInput'), form = $('composerForm'), pinBtn = $('pinBtn');
  const todayItems = $('todayItems'), empty = $('empty');
  const cards = $('cards'), dots = $('dots').children;
  const toastEl = $('toast');

  let promptMode = false;

  function toast(msg) {
    toastEl.textContent = msg;
    toastEl.classList.add('show');
    clearTimeout(toast.t);
    toast.t = setTimeout(() => toastEl.classList.remove('show'), 1800);
  }

  // rail length follows the content: from first dot to last dot
  function layoutRail() {
    const days = board.querySelectorAll('.day');
    const last = days[days.length - 1];
    const rail = board.querySelector('.rail');
    const h = last.offsetTop + 9 - 36 + 20;
    rail.style.setProperty('--rail-h', Math.max(h, 281) + 'px');
  }

  // header cards: dots follow scroll position
  cards.addEventListener('scroll', () => {
    const i = cards.scrollLeft > 150 ? 1 : 0;
    [...dots].forEach((d, n) => d.classList.toggle('on', n === i));
  });

  // composer
  function openComposer() {
    composer.classList.add('open');
    phone.classList.add('keyboard');
    input.placeholder = promptMode ? 'answer the prompt…' : 'Whats on your mind...';
    input.focus();
    sync();
  }
  function closeComposer() {
    composer.classList.remove('open');
    phone.classList.remove('keyboard');
    input.value = '';
    promptMode = false;
  }
  function sync() { pinBtn.disabled = !input.value.trim(); }

  $('composerPill').addEventListener('click', openComposer);
  input.addEventListener('input', sync);
  input.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeComposer(); });
  board.addEventListener('pointerdown', () => { if (composer.classList.contains('open') && !input.value.trim()) closeComposer(); });

  // prompt "+" points the next post at the prompt
  $('promptAdd').addEventListener('click', () => {
    if ($('promptAdd').classList.contains('answered')) return;
    promptMode = true;
    openComposer();
  });

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const text = input.value.trim();
    if (!text) return;

    // over ~280 chars would become a folded note (not in this prototype yet)
    const note = document.createElement('article');
    note.className = 'item note';
    const rot = (Math.random() * 6 - 3).toFixed(2) + 'deg';
    note.style.setProperty('--rot', rot);
    note.style.transform = `rotate(${rot})`;
    note.textContent = text;
    const pin = new Image();
    pin.src = 'assets/pin.svg'; pin.className = 'pin'; pin.alt = '';
    note.prepend(pin);
    todayItems.appendChild(note);

    empty.hidden = true;
    if (promptMode) {
      const btn = $('promptAdd');
      btn.textContent = 'Tue 3';
      btn.classList.add('answered');
      toast('pinned to the prompt');
    }
    closeComposer();
    layoutRail();
    board.scrollTo({ top: board.scrollHeight, behavior: 'smooth' });
  });

  // tabs
  const stubCopy = {
    friends: ['Friends', 'Doorbell, boards you can see, guest list. (FRN-01 — not designed yet)'],
    shelf: ['Shelf', 'Sealed months stack up here like zines. (ARC-01 — not designed yet)'],
  };
  document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t === tab));
      const name = tab.dataset.tab;
      const stub = $('stub');
      composer.hidden = name !== 'bulletin';
      if (name === 'bulletin') { stub.hidden = true; return; }
      $('stubTitle').textContent = stubCopy[name][0];
      $('stubBody').textContent = stubCopy[name][1];
      stub.hidden = false;
    });
  });

  // desktop: scale the 402x874 frame to fit short windows
  function fit() {
    const s = Math.min(1, window.innerHeight / 874, window.innerWidth / 402);
    document.documentElement.style.setProperty('--fit', s);
  }
  window.addEventListener('resize', fit);
  fit();

  layoutRail();
})();
