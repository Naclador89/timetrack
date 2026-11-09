// Fills the weekly project time form of APplus 7 (ProZeitWochenEingabe).
// Spec: docs/specs/booking-transfer.md §6. Never books: the user clicks
// "Buchen" himself. Talks to the app through window.chrome.webview.
(() => {
  if (window.TimeTrackBooking) return;

  const post = (message) => window.chrome.webview.postMessage(message);
  const field = (name, root = document) =>
    root.querySelector(`[name="${name}"]`);
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  function pageReady() {
    try {
      return (
        typeof app !== 'undefined' &&
        app.readyState === 'ready' &&
        typeof windowLoaded !== 'undefined' &&
        windowLoaded === true
      );
    } catch (e) {
      return false;
    }
  }

  // Everything the script relies on; missing parts stop it (§6.1).
  function missingParts() {
    const missing = [];
    for (const n of ['KW', 'JAHR', 'PROJEKT', 'ANP_AUFTRAG', 'DAUER']) {
      if (!field(n)) missing.push(n);
    }
    if (!document.getElementById('EDITOR')) missing.push('EDITOR');
    if (!document.getElementById('lastrow')) missing.push('lastrow');
    const fns = {
      setVonBis: typeof setVonBis,
      handleClearAll: typeof handleClearAll,
      setRowSums: typeof setRowSums,
      setColSums: typeof setColSums,
    };
    for (const [n, t] of Object.entries(fns)) {
      if (t !== 'function') missing.push(n);
    }
    if (!app.form || typeof app.form.setFieldData !== 'function') {
      missing.push('app.form');
    }
    if (!app.soap || !app.job) missing.push('app.soap/app.job');
    return missing;
  }

  const body = () => document.getElementById('EDITOR').tBodies[0];
  const dataRows = () => [...body().rows].filter((r) => r.id !== 'lastrow');

  function hasData() {
    return dataRows().some((tr) =>
      [...tr.querySelectorAll('input[name="PROJEKT"], input[name="DAUER"]')]
        .some((i) => i.value.trim() !== ''),
    );
  }

  // Reports a started booking job (§7).
  function hookBooking() {
    if (app.job.startJob.__timetrack) return;
    const original = app.job.startJob;
    const wrapped = function (...args) {
      const result = original.apply(this, args);
      if (args[2] === 'insertWochenXmlJob') {
        Promise.resolve(result).then(
          () => post({ type: 'booked' }),
          () => {},
        );
      }
      return result;
    };
    wrapped.__timetrack = true;
    app.job.startJob = wrapped;
  }

  // Adds a row as the page does on Tab in the last cell (checkClone).
  async function addRow() {
    const tr = body().insertBefore(
      body().rows[0].cloneNode(true),
      document.getElementById('lastrow'),
    );
    for (const i of tr.getElementsByTagName('input')) i.value = '';
    for (const t of tr.getElementsByTagName('textarea')) t.value = '';
    await app.form.setClonedNodes(tr, false);
    try {
      checkCloneInserted = true;
    } catch (e) {
      // older page versions
    }
    return tr;
  }

  async function attach() {
    const until = Date.now() + 30000;
    while (!pageReady()) {
      if (Date.now() > until) {
        post({ type: 'error', code: 'timeout' });
        return;
      }
      await sleep(200);
    }
    const missing = missingParts();
    if (missing.length) {
      post({ type: 'error', code: 'unexpectedPage', detail: missing.join(', ') });
      return;
    }
    hookBooking();
    post({ type: 'ready', hasData: hasData() });
  }

  // data: {year, week, rows: [{project, order, seconds: [7]}]}
  async function fill(data, clear) {
    try {
      if (clear) handleClearAll();
      const svc = app.soap.call('project/prozeit');
      const unknown = [];
      const valid = [];
      for (const row of data.rows) {
        let number = null;
        try {
          number = svc.checkProjekt(row.project);
        } catch (e) {
          number = null;
        }
        if (number) valid.push({ ...row, number });
        else unknown.push(row.project);
      }
      // Rows first, so that setVonBis sets the dates and locked days of all.
      while (dataRows().length < valid.length) await addRow();
      await app.form.setFieldData(field('JAHR'), String(data.year));
      await app.form.setFieldData(field('KW'), String(data.week));
      await setVonBis({ target: field('KW') });
      const locked = new Set();
      const rows = dataRows();
      for (let r = 0; r < valid.length; r++) {
        const row = valid[r];
        const tr = rows[r];
        await app.form.setFieldData(field('PROJEKT', tr), row.number);
        const name = field('ANPPROJNAME', tr);
        if (name) {
          try {
            name.value = svc.getProjektName(row.number) || '';
            name.title = name.value;
          } catch (e) {
            // the name is only shown
          }
        }
        if (row.order) {
          await app.form.setFieldData(field('ANP_AUFTRAG', tr), row.order);
        }
        const cells = tr.querySelectorAll('input[name="DAUER"]');
        for (let d = 0; d < 7; d++) {
          if (!row.seconds[d]) continue;
          if (cells[d].disabled) {
            locked.add(d);
            continue;
          }
          await app.form.setFieldData(cells[d], row.seconds[d]);
        }
      }
      await setRowSums();
      await setColSums();
      post({
        type: 'filled',
        rows: valid.length,
        unknown,
        locked: [...locked].sort(),
      });
    } catch (e) {
      post({ type: 'error', code: 'fill', detail: String((e && e.message) || e) });
    }
  }

  window.TimeTrackBooking = { attach, fill };
})();
