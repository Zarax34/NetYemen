# NETYEMEN CARD ENCRYPTION DESIGN (V2.0 — PGCRYPTO CHOSEN)

**Task ID:** CARD-ENC-DESIGN / CARD-PGCRYPTO
**Document Code:** `CARD-ENCRYPTION-DESIGN.md`
**Classification:** `BOUND_CONTRACT`
**Scope:** تصميم طبقة تشفير كروت الإنترنت داخل قاعدة البيانات (`pgcrypto` + Supabase Vault)، وربطها بدالتي `admin_ingest_card_vault_batch` و`reveal_purchase_card_secret`، بما يطابق التوصية الأصلية لقرار `OD-CARD-01`.

> **قرار بشري:** بعد عرض الخيارين في الإصدار V1.0 من هذا المستند (Envelope/Edge مقابل `pgcrypto` داخل القاعدة)، اختار صاحب القرار البشري **`pgcrypto` داخل القاعدة** — أي توصية `OD-CARD-01` الأصلية بحرفيتها. هذا الإصدار (V2.0) هو التصميم المعتمد؛ تصميم Envelope/Edge السابق موثّق في القسم 7 كـ "خيار مدروس، غير مختار" لسجل القرار فقط، وكوده المصدري **حُذف** (كان في `supabase/functions/encrypt-cards/`, `supabase/functions/reveal-card/`, `supabase/functions/_shared/crypto.ts`).

---

## 0. ملخص تنفيذي

الجداول والدوال الخاصة بخزنة الكروت مبنية بالفعل في قاعدة البيانات (`supabase/migrations/20260808210000_netyemen_v1_external_pilot_binding.sql`):

* جدول `card_vault` بعمود `ciphertext bytea` (زائداً أعمدة `nonce`/`auth_tag`/`key_version` التي كانت لازمة لتصميم Envelope السابق فقط).
* دالة `admin_ingest_card_vault_batch(p_network_id, p_package_id, p_cards jsonb[], p_key_version)`.
* دالة `reveal_purchase_card_secret(p_purchase_id)`.

**المشكلة الأصلية:** لا يوجد أي طرف يحمل مفتاح التشفير أو يُجري التشفير/فك التشفير فعلياً — كروت الإنترنت لا يمكن رفعها ولا كشفها.

**الحل المعتمد الآن (`supabase/migrations/20260908120000_card_pgcrypto.sql`):**

* مفتاح واحد (Passphrase) يعيش **حصراً** داخل Supabase Vault (`vault.decrypted_secrets`, الاسم `card_master_key`) — لا يُقرأ إلا من داخل دالة SECURITY DEFINER واحدة (`public.get_card_master_key()`) غير الممنوحة (`GRANT`) لأي دور عميل (`anon`/`authenticated`).
* `admin_ingest_card_vault_batch` تستقبل الآن **أرقام PIN نصية صريحة** (`p_cards[i].pin`) وتُشفّرها فوراً عبر `pgp_sym_encrypt(pin, get_card_master_key())` قبل الإدخال — النص الصريح لا يغادر معاملة الدالة نفسها.
* `reveal_purchase_card_secret` تُفكّ التشفير عبر `pgp_sym_decrypt(ciphertext, get_card_master_key())` وتُعيد `{card_pin}` **صريحاً** لصاحب الشراء المتحقَّق منه فقط، ضمن نفس معاملة التحقق من الملكية وكتابة سجل التدقيق — فلا يوجد أي حد فاصل شبكي (Edge Function) يمكن أن يحمل ثغرة تحقق منفصلة.
* لا يوجد بعد الآن أي مفتاح أو نص صريح خارج قاعدة البيانات إطلاقاً — لا في تطبيق الإدارة، ولا في أسرار Edge Function، ولا في التطبيق نفسه إلا كنتيجة عرض نهائية للمشتري.

---

## 1. مطابقة القرار المسجَّل `OD-CARD-01`

القرار `OD-CARD-01` في `docs/NETYEMEN-DECISION-REGISTER-01.md` أوصى بالخيار 1: **تشفير عمود PostgreSQL عبر `pgcrypto`** بمفتاح رئيسي داخل قاعدة البيانات، يُفك حصراً داخل دالة RPC بصلاحية `SECURITY DEFINER`. **هذا هو التصميم المعتمد الآن بحرفيته.**

| | الخيار 1 (المعتمد) — `pgcrypto` + Supabase Vault | الخيار 2/3 (مدروس، غير مختار) — Envelope عبر Edge Function |
|---|---|---|
| **موقع المفتاح** | داخل قاعدة البيانات (Supabase Vault، مُشفَّر بـ pgsodium) | أسرار Supabase Edge Functions (خارج القاعدة) |
| **من يُجري التشفير/الفك** | دالة SQL واحدة (`SECURITY DEFINER`)، ضمن نفس معاملة RPC | عملية شبكة منفصلة (Deno Edge Function) |
| **متطلبات المخطط** | عمود `ciphertext` واحد فقط؛ `nonce`/`auth_tag`/`key_version` غير لازمة | يتطلب أعمدة `nonce`/`auth_tag`/`key_version` منفصلة |
| **زمن الاستجابة** | أسرع (بدون قفزة شبكة إضافية) | أبطأ قليلاً (استدعاء Edge Function منفصل) |
| **سطح الهجوم** | نقطة ثقة واحدة (القاعدة + Vault) | نقطتا ثقة (القاعدة + أسرار Edge Function)، لكن تسرّب القاعدة وحدها لا يكفي |
| **تعقيد التدوير** | يتطلب إعادة تشفير كل الصفوف عند تغيير المفتاح (لا يوجد `key_version` لكل صف) | يدعم تعدد `key_version` حيّة في آن واحد دون إعادة تشفير |

**القرار النهائي:** `OD-CARD-01` ينتقل من `OPEN_DECISION` إلى `BOUND` — **الخيار 1 (`pgcrypto` + Vault)** هو التصميم المعتمد والوحيد قيد التنفيذ. الجدول أعلاه يُبقي مقايضة التدوير موثّقة صراحةً: تدوير المفتاح لاحقاً عملية صيانة (إعادة تشفير كل صف بمفتاح جديد ضمن معاملة واحدة)، وليست تبديل `key_version` لكل صف كما في التصميم البديل.

### 1.1 لماذا هذا الخيار يغلق فجوة اكتُشفت في محاولة سابقة

فرع عمل سابق (`NY-V1-EXTERNAL-PILOT-BINDING-001`) أضاف مساراً جزئياً (`notification-transport-adapter`, إجراء `decrypt_card_secret`) يفك تشفير مغلّف **يستقبله من العميل مباشرة**، دون أن يستدعي `reveal_purchase_card_secret` بنفسه — أي أن التحقق من "طالب الكشف = صاحب الشراء" لم يكن مضموناً داخل حدود تلك الدالة نفسها. تصميم Envelope/Edge في الإصدار V1.0 من هذا المستند أغلق تلك الفجوة بجعل `reveal-card` تستدعي RPC بنفسها.

التصميم الحالي (`pgcrypto`) يُزيل هذه الفئة من الفجوات بالكامل ببنيتها: **لا يوجد حد فاصل شبكي منفصل يمكن أن يُساء استخدامه أصلاً** — التحقق من الملكية، وفك التشفير، وكتابة سجل التدقيق تقع كلها داخل معاملة SQL واحدة غير قابلة للتجزئة (`reveal_purchase_card_secret`). لا يمكن لأي طرف تمرير "مغلّف معترَض" لأن المغلّف لم يعد يغادر القاعدة أصلاً في أي مسار.

---

## 2. تصميم `pgcrypto` + Supabase Vault

* **الخوارزمية:** `pgp_sym_encrypt`/`pgp_sym_decrypt` من امتداد `pgcrypto` (PGP رمزي متماثل بمفتاح نصي/Passphrase) — تُضمِّن دالتا pgcrypto ذاتياً الملح (salt) ومتجه التهيئة وقيمة التكامل داخل قيمة `bytea` واحدة، فلا حاجة لأعمدة `nonce`/`auth_tag` منفصلة.
* **موقع المفتاح:** Supabase Vault (`vault.secrets` / `vault.decrypted_secrets`، مبني على `pgsodium`) — اسم السر `card_master_key`. لا يُقرأ إلا عبر `public.get_card_master_key()`، وهي دالة `SECURITY DEFINER` **غير ممنوحة (`GRANT`) لأي دور عميل** (`anon`, `authenticated`) — يمكن فقط لدوال `SECURITY DEFINER` أخرى مملوكة لنفس الدور استدعاءها.
* **خطوة التفعيل (بشرية، خارج نطاق هذا المستند):** توليد Passphrase عشوائي طويل (مثل ناتج `openssl rand -base64 48`) وتخزينه عبر `vault.create_secret(...)` — التعليمة الدقيقة موثّقة كـ`-- APPLY STEP` أعلى ملف الهجرة `supabase/migrations/20260908120000_card_pgcrypto.sql`، ولم تُنفَّذ بعد ولا تحمل أي قيمة حقيقية داخل هذا المستودع.
* **تدوير المفتاح:** لا يوجد `key_version` لكل صف بعد الآن — مفتاح حيّ واحد فقط. تدوير المفتاح عملية صيانة صريحة: إنشاء سر جديد باسم مختلف، إعادة تشفير كل صفوف `card_vault` ضمن معاملة واحدة (`pgp_sym_encrypt(pgp_sym_decrypt(ciphertext, old_key), new_key)`)، ثم تحديث `get_card_master_key()` لتقرأ السر الجديد. موثّقة كتعليق في ملف الهجرة.

---

## 3. تدفق إدخال الإدارة (Admin Ingest)

لا يوجد Edge Function بعد الآن — التطبيق (شاشة إدارة أو تطبيق الإدارة) يستدعي RPC مباشرة بتوكن المستخدم نفسه:

```
مسؤول المنصة (JWT: platform_admin) أو مالك شبكة (can_manage_network)
   │
   ▼
supabase.rpc('admin_ingest_card_vault_batch', {
  p_network_id, p_package_id,
  p_cards: [{ pin: '<PIN صريح>', expires_at? }, ...]
})
   │
   ├─ 1) auth.uid() موجود؟ وإلا UNAUTHENTICATED
   ├─ 2) الحساب profiles.account_status = 'active'؟ وإلا INACTIVE_PROFILE
   ├─ 3) has_platform_role('platform_admin') أو can_manage_network(network_id)؟ وإلا FORBIDDEN_ROLE
   ├─ 4) package_id ينتمي فعلاً لـ network_id؟ وإلا INVALID_PACKAGE_REFERENCE
   ├─ 5) get_card_master_key() — إن كان السر غير مُهيَّأ بعد: CARD_MASTER_KEY_NOT_CONFIGURED
   └─ 6) لكل كرت: pgp_sym_encrypt(pin, master_key) → إدخال في card_vault (state='available')
          (كل هذا ضمن معاملة واحدة؛ النص الصريح لا يغادر السياق التنفيذي لهذه الدالة إطلاقاً)
   │
   ▼
الرد: { batch_id, ingested_count }
```

---

## 4. تدفق كشف العميل (Customer Reveal)

```
العميل الذي أتم عملية شراء (JWT: مستخدم مصادَق)
   │
   ▼
supabase.rpc('reveal_purchase_card_secret', { p_purchase_id })
   │
   ├─ auth.uid() = purchase_records.user_id؟ وإلا NOT_FOUND (لا تُفصح حتى بوجود عملية لغير صاحبها)
   ├─ purchase_records.status = 'completed'؟ وإلا INVALID_STATE
   ├─ card_vault.state = 'sold' (وليست quarantined/invalidated)؟ وإلا CARD_BLOCKED / INVALID_CARD_STATE
   ├─ pgp_sym_decrypt(ciphertext, get_card_master_key()) — فشل الفك (مفتاح مُدار خطأً/صف تالف): DECRYPTION_FAILED
   │      (الفشل هنا يُلغي المعاملة بالكامل: لا تُسجَّل عملية كشف ولا يبدأ عدّاد نافذة النزاع)
   ├─ عند النجاح: تُسجّل first_revealed_at / dispute_deadline (+30 دقيقة) / reveal_count
   ├─ تكتب حدث تدقيق CARD_REVEALED عبر record_audit_event (BR-AUDIT-001)
   └─ تُعيد { purchase_id, status: 'revealed', card_pin }  ← داخل نفس المعاملة، لصاحب الشراء فقط
```

---

## 5. مطابقة ضوابط الأمان والخصوصية

مطابقةً لتصنيف `CARD_SECRET` في `docs/NETYEMEN-DATA-CLASSIFICATION-AND-PRIVACY-01.md` ("ممنوع في السجلات إطلاقاً" / "يُفصح حصراً للمشتري"):

* **لا تسجيل مطلقاً (`STRICTLY FORBIDDEN IN LOGS`):** لا يوجد أي `RAISE NOTICE`/سجل لأي نص صريح أو مادة تشفير في الدالتين. رسائل الأخطاء (`DECRYPTION_FAILED`, ...) لا تتضمن محتوى الكرت.
* **`BR-CARD-005` (عقد الكشف للمشتري حصراً):** مطبَّق داخل `reveal_purchase_card_secret` بلا تغيير عن التصميم السابق — التحقق من `auth.uid() = purchase_records.user_id` لا يزال أول شرط قبل أي وصول للكرت.
* **`BR-SUPPORT-002` (كشف مقيّد داخل تذكرة دعم):** لا يزال خارج نطاق هذا المستند — `reveal_purchase_card_secret` تتحقق من ملكية الشراء فقط، لا من سياق تذكرة دعم. يلزم إجراء RPC منفصل بمنطق تفويض مختلف (يُرصد كعمل مستقبلي).
* **`BR-ADMIN-002` (منع تجاوز المسؤول لمنطق الشراء):** `admin_ingest_card_vault_batch` تُدخل كروتاً بحالة `available` فقط، ولا تستدعي أي مسار كشف أو شراء؛ لا مسار يتيح للمسؤول انتحال هوية مشترٍ أو كشف كرت دون شراء فعلي.
* **التدقيق (`BR-AUDIT-001`):** كل كشف كرت يُسجَّل عبر `record_audit_event('CARD_REVEALED', ...)` **قبل** إعادة القيمة الصريحة للمتصل، وضمن نفس المعاملة التي تحققت من الملكية — لا يمكن أن ينجح الكشف دون تسجيل تدقيقي، ولا يمكن أن يُسجَّل تدقيق لكشف لم يحدث فعلياً (فشل الفك يُلغي المعاملة بالكامل).
* **عزل مفتاح Service-Role:** لا حاجة لأي مفتاح `service-role` في أي مسار — العميل والإدارة كلاهما يستدعيان RPC بتوكن المستخدم نفسه، وتُطبَّق كل قيود RLS/الأدوار العادية دون توسيع صلاحيات.
* **عزل المفتاح عن العميل:** `get_card_master_key()` غير ممنوحة (`GRANT`) لأي دور عميل — لا يمكن لأي طلب REST/RPC من التطبيق قراءة قيمة المفتاح مطلقاً، بعكس تصميم Envelope الذي كان المفتاح فيه يعيش خارج القاعدة (في أسرار Edge Function) وبالتالي يمكن نظرياً لأي كود يعمل داخل تلك الدالة الوصول إليه.

---

## 6. خارج نطاق هذا المستند (`CARD-ENC-DEPLOY` / تطبيق حي)

المهام التالية بشرية بالكامل ومملوكة من Michael، ولا تُنفَّذ هنا:

* تشغيل `supabase db push` / تطبيق الهجرة `20260908120000_card_pgcrypto.sql` على القاعدة الحية (لا يوجد Token بعد).
* توليد الـ Passphrase الفعلي وتنفيذ استدعاء `vault.create_secret(...)` (التعليمة الدقيقة أعلى ملف الهجرة، مع Placeholder لا قيمة حقيقية).
* اختبار قبول E2E (رفع دفعة كروت حقيقية ثم كشف عملية شراء) على بيئة معزولة قبل الإطلاق الفعلي.

---

## 7. ملحق تاريخي — الخيار المدروس وغير المختار: Envelope عبر Edge Function

الإصدار V1.0 من هذا المستند صمّم بديلاً كاملاً (Envelope Encryption AES-256-GCM عبر دالتي Edge منفصلتين، مع مفتاح في أسرار Supabase بدل Vault) لأنه كان يطابق حرفياً مخطط `card_vault` كما كان مبنياً وقتها (`nonce`/`auth_tag`/`key_version`). بعد اختيار الإنسان لمسار `pgcrypto`:

* حُذف كود المصدر الخاص به بالكامل: `supabase/functions/encrypt-cards/index.ts`, `supabase/functions/reveal-card/index.ts`, `supabase/functions/_shared/crypto.ts`.
* حُذفت أعمدة `nonce`/`auth_tag`/`key_version` من `card_vault` (كانت خاصة بذلك التصميم فقط؛ الجدول كان فارغاً `0` صفوف فلا فقدان بيانات).
* أقسامه التفصيلية (تدفقات Edge Function، متغيرات البيئة `CARD_MASTER_KEY_<VERSION>`، إلخ) لا تزال قابلة للاطلاع في تاريخ Git لهذا الملف (commit `aeea7a3` على فرع `fix/rtl-localization-and-release-signing`) إن احتاج التصميم لمراجعة لاحقة أو الرجوع إليه.

---

## 8. الملفات المرجعية لهذا التصميم

| الملف | الدور |
|---|---|
| `supabase/migrations/20260908120000_card_pgcrypto.sql` | الهجرة الكاملة: `pgcrypto` + `get_card_master_key()` + إعادة كتابة الدوال الثلاث + حذف الأعمدة غير اللازمة |
| `lib/models/purchase_model.dart` | نوع نتيجة الكشف الصريح الجديد (بديل `CardSecretEnvelope`) |
| `lib/services/supabase_service.dart` | `revealPurchaseCard` يستدعي `reveal_purchase_card_secret` ويعيد PIN صريحاً |
| `lib/screens/home/purchase_success_screen.dart`, `lib/screens/purchases/purchases_screen.dart` | عرض PIN مموَّهاً (`12****89`) مع كشف عند اللمس ونسخ |
