// Captures d'écran des procédures, prises sur la base de démonstration.
// Lancé par bin/procedures-captures : ne pas l'appeler directement.
// Usage : node lib/demo/captures.mjs <url de l'appli> <port de débogage Chrome> <dossier de sortie> [filtre]
import fs from "node:fs";

const [base, port, outDir, only] = process.argv.slice(2);
const demo = JSON.parse(fs.readFileSync("tmp/procedures_demo.json", "utf8"));
const PHONE = 390, DESKTOP = 1180;

// user : compte de démonstration ; clip : [de, à] = du haut du 1er élément au bas du 2e ;
// before : JavaScript exécuté avant la capture (ouvrir une fenêtre, cliquer…).
const shots = [
  { name: "op-a-reprendre", user: "camille", path: "/toys?filter=review", width: PHONE, clip: [".filter-tab-rework", ".row.g-3 > div:nth-child(1) .toy-card"], pad: 8 },
  { name: "op-reprise", user: "camille", path: `/toys/${demo.orange}/edit`, width: PHONE, clip: [".quality-round--past", "form[action^='/toys'] .d-grid"] },
  { name: "op-ecarter", user: "camille", path: `/boxes/${demo.mixed_box}`, width: PHONE,
    before: "document.querySelector('[data-bs-target=\"#quickDiscardModal\"]').click()", wait: 900, clip: [".modal-header", ".discard-destinations"], pad: 10 },
  { name: "op-a-terminer", user: "camille", path: `/boxes/${demo.main_box}`, width: PHONE, clip: [".toy-show-actions", ".drafts-strip"] },

  { name: "tri-nouvelle-caisse", user: "ines", path: "/boxes/new", width: PHONE, viewport: 520 },
  { name: "tri-etiquette", user: "ines", path: `/boxes/${demo.draft_box}/edit?new=true`, width: PHONE, viewport: 640 },
  { name: "tri-liste", user: "ines", path: "/boxes", width: PHONE, viewport: 860 },
  { name: "tri-vide", user: "ines", path: `/boxes/${demo.main_box}`, width: PHONE, clip: [".detail-card", ".toy-show-actions"], pad: 24 },

  { name: "cq-premier-tour", user: "sophie", path: `/toys/${demo.first_round}/verify`, width: PHONE,
    before: "document.querySelector('#cq_cause_nettoyage').click(); document.querySelector('#cq_cause_photo').click()", wait: 1800,
    clip: [".verify-conditions", ".verify-decisions + .verify-decisions"] },
  { name: "cq-deuxieme-tour", user: "sophie", path: `/toys/${demo.second_round}/verify`, width: PHONE,
    before: "document.querySelector('.cause-legend').remove()", clip: [".quality-round--past", ".verify-decisions"] },
  { name: "cq-arbitrage", user: "sophie", path: `/toys/${demo.arbitrage}/verify`, width: PHONE, clip: [".quality-round:not(.quality-round--past)", ".verify-decisions + .verify-decisions"] },
  { name: "cq-onglets", user: "sophie", path: "/toys?filter=review", width: PHONE, viewport: 800 },
  { name: "cq-confier", user: "sophie", path: `/toys/${demo.late}`, width: PHONE, clip: [".toy-show-actions", ".reassign-box"] },

  { name: "tb-periode", user: "sophie", path: "/dashboard?period=four_weeks", width: DESKTOP, clip: [".period-pills", ".quality-now"] },
  { name: "tb-premier-coup", user: "sophie", path: "/dashboard?period=four_weeks", width: DESKTOP, clip: [".quality-card", ".kpi-card"] },
  { name: "tb-detail", user: "sophie", path: "/dashboard?period=four_weeks", width: DESKTOP,
    before: "window.scrollTo(0, 560); document.querySelectorAll('.quality-bar-row')[3].click()", wait: 1800, viewport: 760 },
  { name: "tb-operateurs", user: "sophie", path: "/dashboard?period=four_weeks", width: DESKTOP, clip: [".quality-table", ".quality-matrix"], pad: 70 },
  { name: "tb-tri", user: "sophie", path: "/dashboard?period=four_weeks", width: DESKTOP, clip: [".quality-dash > .row >> last", ".quality-dash > .row >> last"] },
  { name: "tb-jour", user: "sophie", path: "/dashboard?period=today", width: DESKTOP, clip: [".quality-card:has(.quality-table--day)", ".quality-card:has(.quality-table--day)"], pad: 6 },
  { name: "tb-objectifs", user: "sophie", path: "/dashboard?period=four_weeks", width: DESKTOP,
    before: "document.querySelector('.quality-settings').open = true", clip: [".quality-settings", ".quality-settings"] }
].filter(shot => !only || shot.name.includes(only));

const sleep = ms => new Promise(r => setTimeout(r, ms));
const tab = await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method: "PUT" })).json();
const ws = new WebSocket(tab.webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener("open", r));
let id = 0; const pending = new Map();
ws.addEventListener("message", m => { const d = JSON.parse(m.data); if (d.id) pending.get(d.id)?.(d); });
const send = (method, params = {}) => new Promise(r => { pending.set(++id, r); ws.send(JSON.stringify({ id, method, params })); });
const run = async expression => (await send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true })).result?.result?.value;
const go = async (url, wait = 1800) => { await send("Page.navigate", { url }); await sleep(wait); await run("document.fonts.ready.then(() => true)"); };

await send("Page.enable");
let current = null;
for (const shot of shots) {
  await send("Emulation.setDeviceMetricsOverride", { width: shot.width, height: shot.viewport || 900, deviceScaleFactor: shot.width < 600 ? 2 : 1.5, mobile: shot.width < 600 });
  if (shot.user !== current) {
    await send("Network.clearBrowserCookies");
    await go(`${base}/users/sign_in`);
    await run(`document.querySelector('#user_email').value = '${shot.user}@example.com';
               document.querySelector('#user_password').value = '${demo.password}';
               document.querySelector('form[action="/users/sign_in"]').requestSubmit(); true`);
    await sleep(2000);
    current = shot.user;
  }
  await go(base + shot.path);
  // Les bandeaux d'outils de développement n'ont rien à faire sur une capture.
  await run("document.querySelectorAll('#bullet-footer, [data-is-bullet-footer], .alert-dismissible').forEach(e => e.remove()); true");
  if (shot.before) { await run(`${shot.before}; true`); await sleep(shot.wait || 400); }

  const params = { format: "jpeg", quality: 88 };
  if (shot.clip) {
    await run("document.querySelectorAll('.bottom-tab-bar').forEach(e => e.style.display = 'none'); true");
    const pick = sel => sel.endsWith(">> last")
      ? `Array.from(document.querySelectorAll(${JSON.stringify(sel.replace(" >> last", ""))})).at(-1)`
      : `document.querySelector(${JSON.stringify(sel)})`;
    const box = await run(`(() => {
      const a = ${pick(shot.clip[0])}, b = ${pick(shot.clip[1])};
      if (!a || !b) return null;
      const ra = a.getBoundingClientRect(), rb = b.getBoundingClientRect();
      return { top: ra.top + scrollY, bottom: rb.bottom + scrollY };
    })()`);
    if (!box) { console.log(`MANQUE ${shot.name} : sélecteur introuvable`); continue; }
    const pad = shot.pad ?? 14;
    params.clip = { x: 0, y: Math.max(box.top - pad, 0), width: shot.width, height: box.bottom - box.top + 2 * pad, scale: 1 };
    params.captureBeyondViewport = true;
  }
  const result = await send("Page.captureScreenshot", params);
  fs.writeFileSync(`${outDir}/${shot.name}.jpg`, Buffer.from(result.result.data, "base64"));
  console.log(`ok ${shot.name}`);
}
await fetch(`http://127.0.0.1:${port}/json/close/${tab.id}`);
ws.close();
