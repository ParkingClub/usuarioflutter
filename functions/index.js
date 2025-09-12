// index.js

// ----------------------------
// Inicialización / Imports
// ----------------------------
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");

initializeApp();

// ----------------------------
// Utilidades
// ----------------------------
const chunk = (arr, size) =>
  Array.from({ length: Math.ceil(arr.length / size) }, (_, i) => arr.slice(i * size, i * size + size));

/** Envío por lotes (≤500) + limpieza de tokens inválidos si se pasa userRef */
async function sendToTokensWithCleanup(tokens, messageBase, userRef /* opcional */) {
  const clean = [...new Set((tokens || []).filter(Boolean))];
  if (!clean.length) return { success: 0, failure: 0, removed: 0 };

  const messaging = getMessaging();
  const batches = chunk(clean, 500); // Límite FCM (multicast) :contentReference[oaicite:3]{index=3}

  let success = 0, failure = 0;
  const toRemove = new Set();

  for (const batch of batches) {
    const resp = await messaging.sendEachForMulticast({ tokens: batch, ...messageBase });
    success += resp.successCount;
    failure += resp.failureCount;

    resp.responses.forEach((r, idx) => {
      if (!r.success) {
        const code = r.error?.code || "";
        if (code.includes("registration-token-not-registered") || code.includes("invalid-argument")) {
          toRemove.add(batch[idx]);
        }
      }
    });
  }

  if (userRef && toRemove.size) {
    await userRef.update({ fcmTokens: FieldValue.arrayRemove(...Array.from(toRemove)) });
  }
  return { success, failure, removed: toRemove.size };
}

/** Construye message base; en FCM los valores de `data` deben ser STRINGS. :contentReference[oaicite:4]{index=4} */
function buildMessageBase({ title, body, data = {} }) {
  const dataStrings = {};
  for (const [k, v] of Object.entries(data)) dataStrings[k] = String(v ?? "");
  return {
    notification: { title, body },
    data: dataStrings,
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default" } } },
  };
}

// ---------------------------------------------------------------------------------
// 1) RECORDATORIO DE PICO Y PLACA (programado)
// ---------------------------------------------------------------------------------
exports.picoPlacaReminder = onSchedule(
  {
    schedule: "0 12 * * 1-5", // 12:00 L-V
    timeZone: "America/Guayaquil",
    region: "us-central1",
    memory: "256MiB",
    timeoutSeconds: 120,
  },
  async () => {
    console.log("Iniciando recordatorio de Pico y Placa (v2)...");
    const picoPlacaMap = { 1: ["1","2"], 2: ["3","4"], 3: ["5","6"], 4: ["7","8"], 5: ["9","0"] };
    const weekday = new Date().getDay(); // 0=Dom
    const restrictedDigits = picoPlacaMap[weekday];
    if (!restrictedDigits) { console.log("Fin de semana: sin restricción."); return; }

    const db = getFirestore();
    const usersSnapshot = await db.collection("users")
      .where("plateLastDigit", "in", restrictedDigits)
      .get();

    if (usersSnapshot.empty) { console.log("Sin usuarios restringidos hoy."); return; }

    const tasks = [];
    usersSnapshot.forEach((doc) => {
      const u = doc.data();
      const tokens = Array.isArray(u.fcmTokens) ? u.fcmTokens.filter(Boolean) : [];
      if (!tokens.length) return;

      const msg = buildMessageBase({
        title: "🚨 Recordatorio de Pico y Placa",
        body: `¡Hola ${u.displayName || "conductor/a"}! Hoy tu vehículo con placa terminada en ${u.plateLastDigit} tiene restricción.`,
        data: { type: "pico_placa", plateLastDigit: String(u.plateLastDigit ?? "") },
      });

      tasks.push(sendToTokensWithCleanup(tokens, msg, doc.ref));
    });

    const res = await Promise.all(tasks);
    const sent = res.reduce((a,r)=>a+r.success,0);
    const failed = res.reduce((a,r)=>a+r.failure,0);
    const removed = res.reduce((a,r)=>a+r.removed,0);
    console.log(`Pico y Placa: ok=${sent} fail=${failed} tokensEliminados=${removed}`);
  }
);

// ---------------------------------------------------------------------------------
// 2) SALUDO DE CUMPLEAÑOS (programado) — tiempo/memoria propios
// ---------------------------------------------------------------------------------
exports.birthdayGreeter = onSchedule(
  {
    schedule: "0 9 * * *",           // 09:00 todos los días
    timeZone: "America/Guayaquil",   // v2 scheduler :contentReference[oaicite:5]{index=5}
    region: "us-central1",
    memory: "512MiB",
    timeoutSeconds: 300,             // ⇐ evita que un global bajo lo mate (no usar setGlobalOptions bajo) :contentReference[oaicite:6]{index=6}
  },
  async () => {
    console.log("Iniciando verificación de cumpleaños...");
    const today = new Date();
    const month = today.getMonth() + 1;
    const day = today.getDate();

    const db = getFirestore();
    const usersSnapshot = await db.collection("users").get();
    if (usersSnapshot.empty) { console.log("No hay usuarios registrados."); return; }

    // Envío por usuario (permite limpiar tokens inválidos)
    const tasks = [];
    usersSnapshot.forEach((doc) => {
      const u = doc.data();
      const b = u.birthday;
      if (!b) return;

      const d = b.toDate ? b.toDate() : new Date(b);
      if ((d.getMonth() + 1) !== month || d.getDate() !== day) return;

      const tokens = Array.isArray(u.fcmTokens) ? u.fcmTokens.filter(Boolean) : [];
      if (!tokens.length) return;

      const msg = buildMessageBase({
        title: `🎉 ¡Feliz Cumpleaños, ${u.displayName || "conductor/a"}!`,
        body:  "Parking Club te desea un día increíble. 🎂",
        data:  { type: "birthday" },
      });

      tasks.push(sendToTokensWithCleanup(tokens, msg, doc.ref));
    });

    const res = await Promise.all(tasks);
    const sent = res.reduce((a,r)=>a+r.success,0);
    const failed = res.reduce((a,r)=>a+r.failure,0);
    const removed = res.reduce((a,r)=>a+r.removed,0);
    console.log(`Cumpleaños: ok=${sent} fail=${failed} tokensEliminados=${removed}`);
  }
);

// ---------------------------------------------------------------------------------
// 3) PROMOCIONES (al crear promotions/{promotionId})
// ---------------------------------------------------------------------------------
exports.sendPromotionalNotification = onDocumentCreated("promotions/{promotionId}", async (event) => {
  const promotion = event.data?.data();
  if (!promotion) { console.warn("Promoción sin datos."); return null; }

  const db = getFirestore();
  const usersSnapshot = await db.collection("users").get();
  if (usersSnapshot.empty) { console.log("No hay usuarios para notificar."); return null; }

  // tokens únicos (no sabemos a qué usuario pertenece cada uno, así que aquí NO podemos limpiar por usuario)
  const all = new Set();
  usersSnapshot.forEach((doc) => {
    const u = doc.data();
    (u.fcmTokens || []).filter(Boolean).forEach((t) => all.add(t));
  });
  const tokens = [...all];
  if (!tokens.length) { console.log("No hay tokens FCM."); return null; }

  const msg = buildMessageBase({
    title: `📣 ${promotion.title || "Nueva promoción"}`,
    body:  String(promotion.body || "Aprovecha nuestras novedades en Parking Club."),
    data:  { type: "promotion", promotionId: String(event.params.promotionId || "") },
  });

  // Envío en lotes (≤500)
  const messaging = getMessaging();
  const batches = chunk(tokens, 500);
  await Promise.all(batches.map((batch) => messaging.sendEachForMulticast({ tokens: batch, ...msg })));
  console.log(`Promoción enviada a ${tokens.length} dispositivos (lotes=${batches.length}).`);
  return null;
});

// ---------------------------------------------------------------------------------
// 4) BIENVENIDA (al completar perfil users/{userId})
// ---------------------------------------------------------------------------------
exports.sendWelcomeNotification = onDocumentUpdated("users/{userId}", async (event) => {
  const before = event.data?.before?.data() || {};
  const after  = event.data?.after?.data()  || {};
  const userRef = event.data?.after?.ref;

  // Dispara solo cuando pasa de null -> valor
  const perfilRecienCompletado = (before.plateLastDigit == null && after.plateLastDigit != null);
  if (!perfilRecienCompletado) return null;

  const tokens = Array.isArray(after.fcmTokens) ? after.fcmTokens.filter(Boolean) : [];
  if (!tokens.length) return null;

  const msg = buildMessageBase({
    title: `👋 ¡Bienvenido, ${after.displayName || "conductor/a"}!`,
    body:  "Tu registro en Parking Club se ha completado.",
    data:  {
      type:  "welcome_message",
      title: `👋 ¡Bienvenido, ${after.displayName || "conductor/a"}!`,
      body:  "Bienvenido al club de parqueaderos más grande del Ecuador.",
    },
  });

  const r = await sendToTokensWithCleanup(tokens, msg, userRef);
  console.log(`Bienvenida: ok=${r.success} fail=${r.failure} tokensEliminados=${r.removed}`);
  return null;
});
