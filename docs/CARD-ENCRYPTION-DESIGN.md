# NETYEMEN CARD ENCRYPTION DESIGN (V1.0)

**Task ID:** CARD-ENC-DESIGN
**Document Code:** `CARD-ENCRYPTION-DESIGN.md`
**Classification:** `PROPOSED_CONTRACT`
**Scope:** تصميم طبقة تشفير كروت الإنترنت (Envelope Encryption عبر Edge Functions) لمطابقة المخطط المبني فعلياً في `card_vault`، وربطها بدالتي `admin_ingest_card_vault_batch` و`reveal_purchase_card_secret` الموجودتين مسبقاً.

---

## 0. ملخص تنفيذي

الجداول والدوال الخاصة بخزنة الكروت مبنية بالفعل في قاعدة البيانات:

* جدول `card_vault` بأعمدة `ciphertext bytea`, `nonce`, `auth_tag`, `key_version`.
* دالة `admin_ingest_card_vault_batch(p_network_id, p_package_id, p_cards jsonb[], p_key_version)` — تتحقق من الصلاحية (`platform_admin` أو مالك الشبكة عبر `can_manage_network`)، ثم تُدخل كل عنصر من `p_cards` **كما هو** (`ciphertext`, `nonce`, `auth_tag`, `expires_at`) داخل معاملة واحدة.
* دالة `reveal_purchase_card_secret(p_purchase_id)` — تتحقق أن طالب الكشف هو صاحب عملية الشراء فعلاً، أن العملية `completed`، وأن حالة الكرت `sold` (وليست `quarantined`/`invalidated`)، ثم تُسجّل زمن أول كشف وموعد نافذة النزاع (30 دقيقة)، وتكتب حدث تدقيق `CARD_REVEALED` عبر `record_audit_event`، وتُعيد الحمولة المشفّرة `{ciphertext_b64, nonce, auth_tag_b64, key_version}`.

**المشكلة:** لا يوجد أي طرف يحمل مفتاح AES أو يُجري التشفير/فك التشفير فعلياً. النتيجة الحالية موثّقة في التطبيق نفسه:

* واجهة الإدارة (`admin/index.html`) تعرض تنبيهاً صريحاً: "رفع الكروت معطّل — ينقص مفتاح التشفير"، وتطلب من المسؤول لصق JSON **مشفّر مسبقاً يدوياً** بدل توليده من نص صريح.
* نموذج العميل (`CardSecretEnvelope` في `lib/models/purchase_model.dart`) يستقبل الحمولة المشفّرة من `reveal_purchase_card_secret` لكنه يوثّق صراحة: "لا توجد بعد آلية لتسليم هذا المفتاح إلى التطبيق، لذا لا يستطيع العميل عرض الرقم".

هذا المستند يصمم الطبقة الناقصة: مفتاح AES-256-GCM يعيش **حصراً** في أسرار Supabase (Edge Function secrets)، ولا يغادر الخادم أبداً — لا إلى تطبيق الإدارة، ولا إلى تطبيق العميل، ولا إلى قاعدة البيانات كنص صريح.

---

## 1. مطابقة القرار المسجَّل `OD-CARD-01`

القرار `OD-CARD-01` في `docs/NETYEMEN-DECISION-REGISTER-01.md` أوصى مبدئياً بالخيار 1 (**تشفير عمود PostgreSQL عبر `pgcrypto`** بمفتاح رئيسي داخل قاعدة البيانات، يُفك حصراً داخل دالة RPC بصلاحية `SECURITY DEFINER`). لكن المخطط والدوال المبنية فعلياً — `card_vault(ciphertext, nonce, auth_tag, key_version)` وشكل الحمولة `{ciphertext, nonce, auth_tag}` — لا يطابقان `pgcrypto` (الذي لا يحتاج عمود `nonce`/`auth_tag` منفصلين، فهو يضمّن كل شيء داخل قيمة واحدة عبر `pgp_sym_encrypt`)، بل يطابقان تماماً **الخيار 2 (Vault / KMS خارج نطاق الجدول)** بصيغة معدّلة: مغلّف AES-GCM قياسي (ciphertext + nonce + auth tag منفصلين)، يُفك خارج قاعدة البيانات.

| | الخيار 1 — `pgcrypto` داخل القاعدة (توصية `OD-CARD-01` الأصلية) | الخيار 2/3 — Envelope Encryption عبر Edge Function (المطابق للمبني فعلياً) |
|---|---|---|
| **موقع المفتاح** | داخل قاعدة البيانات (دالة أو إعداد GUC) | أسرار Supabase Edge Functions فقط |
| **متطلبات المخطط** | عمود مشفّر واحد يكفي؛ لا حاجة لـ `nonce`/`auth_tag` منفصلين | يطابق `card_vault` المبني حرفياً |
| **مخاطر تسرّب القاعدة** | تسرّب نسخة احتياطية للقاعدة + تسرّب المفتاح (إن كان GUC أو جدول) يكشف كل الكروت | تسرّب نسخة القاعدة وحده **لا يكفي**؛ يلزم أيضاً تسرّب أسرار Edge Function المنفصلة |
| **زمن الاستجابة** | أسرع (بدون قفزة شبكة) | أبطأ قليلاً (استدعاء Edge Function) |
| **التوافق مع الكود الحالي** | يتطلب إعادة تصميم `card_vault` والدالتين | لا يتطلب أي تغيير على المخطط أو توقيعات الدوال |

**التوصية:** اعتماد **مسار Edge Function (Envelope Encryption)** رسمياً بدل توصية `pgcrypto` الأصلية، لأنه يطابق ما هو مبني فعلياً دون أي هجرة (migration) إضافية، ويحقق نفس هدف `OD-CARD-01` الأمني (عزل مادة التشفير عن نص الكرت الصريح) بعزل أقوى (تسرّب القاعدة وحده لا يكفي لفك أي كرت). يُسجَّل هذا كتحديث لـ `OD-CARD-01`: **الحالة تنتقل من `OPEN_DECISION` إلى `BOUND` بموجب هذا المستند**، والخيار المعتمد هو Envelope Encryption عبر Edge Function، لا `pgcrypto`.

### 1.1 ملاحظة تصالح مع محاولة سابقة

فرع عمل سابق (التزام `NY-V1-EXTERNAL-PILOT-BINDING-001`) أضاف بالفعل مسار جزئي داخل دالة `notification-transport-adapter` (إجراء `decrypt_card_secret`) ووحدة `crypto.ts` مطابقة لهذا التصميم في التشفير/فك التشفير. لكن ذلك المسار له فجوتان يعالجهما هذا التصميم:

1. **مسار الإدخال غير مكتمل:** لا يوجد إجراء `encrypt_card_secret` مطلقاً؛ شاشة الإدارة هناك ما زالت تطلب لصق `ciphertext`/`nonce`/`auth_tag` جاهزة يدوياً — أي أن التشفير الفعلي لم يُربط قط.
2. **مسار الكشف لا يعيد التحقق من الملكية:** معالج `decrypt_card_secret` هناك يستقبل `ciphertext_b64`/`nonce`/`auth_tag_b64` **من العميل مباشرة** ويفك تشفيرها دون أي استدعاء لـ `reveal_purchase_card_secret` بداخله — أي أن التحقق من "طالب الكشف = صاحب الشراء" يقع بالكامل على العميل (الذي يُفترض أن يستدعي `reveal_purchase_card_secret` أولاً بنفسه). أي طرف مصادَق يملك حمولة معترَضة (Ciphertext) لعملية شراء غيره يمكنه تمريرها لهذه الدالة وفكّها.

هذا التصميم يغلق الفجوتين معاً بتصميم أحادي الاتجاه: **دالة `reveal-card` تستدعي `reveal_purchase_card_secret` بنفسها من الخادم** (بتوكن الطالب نفسه)، فلا يُقبل مطلقاً مغلّف قادم من العميل، ويبقى التحقق من الملكية وتسجيل التدقيق داخل حدود RPC واحدة موثوقة. كما تُضاف دالة `encrypt-cards` المفقودة لإغلاق الفجوة الأولى.

---

## 2. تصميم Envelope Encryption

* **الخوارزمية:** AES-256-GCM (مفتاح 32 بايت، nonce عشوائي 12 بايت لكل عملية تشفير، auth tag 16 بايت).
* **موقع المفتاح:** حصراً كأسرار Supabase Edge Function (`supabase secrets set`)، ولا يُقرأ إلا عبر `Deno.env.get`. لا يوجد أي احتياطي (fallback) لمفتاح تجريبي داخل `supabase/functions/_shared/crypto.ts` — إن غاب المتغير، تفشل الدالة بـ `503 SERVICE_UNAVAILABLE` بدل توليد مفتاح بديل بصمت. (هذا تعمّد أكثر تحفّظاً من نمط `crypto.ts` السابق في `notification-transport-adapter`، الذي كان يشتق مفتاح `TEST_ONLY` عند غياب المتغير — سلوك مناسب محلياً لكنه خطر لو نُسي في الإنتاج).
* **تدوير المفاتيح (`key_version`):** اسم متغير البيئة يُشتق آلياً من `key_version` بالصيغة `CARD_MASTER_KEY_<VERSION>` (بأحرف كبيرة، وأي رمز غير أبجدي رقمي يتحول لشرطة سفلية) — مثلاً `key_version = "v1"` ⇒ `CARD_MASTER_KEY_V1`. الإصدار النشط الافتراضي للتشفير الجديد يُقرأ من `CARD_ACTIVE_KEY_VERSION` (افتراضياً `"v1"`)، بينما فك التشفير يقرأ دائماً `key_version` المخزّن مع كل صف في `card_vault` — أي أن تدوير المفتاح لا يكسر كشف الكروت القديمة طالما بقي متغير البيئة القديم معرَّفاً حتى تُكشف/تنتهي صلاحية كل الكروت المشفّرة به.
* **الحمولة (Envelope):** `{ciphertext (base64), nonce (base64), auth_tag (base64)}` — يطابق حرفياً ما تتوقعه `admin_ingest_card_vault_batch` (`v_card->>'ciphertext'` يُفك base64 إلى `bytea`، بينما `nonce`/`auth_tag` نصّان يُخزَّنان كما هما) وما تُعيده `reveal_purchase_card_secret` (`ciphertext_b64`, `nonce`, `auth_tag_b64`).

---

## 3. تدفق إدخال الإدارة (Admin Ingest)

```
مسؤول المنصة (JWT: platform_admin)
   │
   ▼
POST /functions/v1/encrypt-cards
   { network_id, package_id, key_version?, cards: [{plaintext_pin, expires_at?}] }
   │
   ├─ 1) التحقق: هل يملك مقدّم الطلب دور platform_admin؟
   │      → عبر استدعاء RPC has_platform_role('platform_admin') بتوكن المستخدم نفسه
   │      → غير ذلك: 403 FORBIDDEN_ROLE (ترفض الدالة قبل أي عملية تشفير)
   │
   ├─ 2) تحميل مفتاح AES النشط (CARD_MASTER_KEY_<VERSION> من الأسرار)
   │      → غير موجود: 503 SERVICE_UNAVAILABLE (لا تشفير بمفتاح بديل)
   │
   ├─ 3) لكل كرت: aes256GcmEncrypt(plaintext_pin) → {ciphertext, nonce, auth_tag}
   │      (النص الصريح يبقى في الذاكرة فقط لمدة الطلب، ولا يُسجَّل في أي سجل)
   │
   └─ 4) استدعاء admin_ingest_card_vault_batch(network_id, package_id, envelopes[], key_version)
          بتوكن المستخدم نفسه (لا مفتاح service-role) — الدالة تعيد التحقق من
          الصلاحية داخلياً وتُدخل الدفعة بمعاملة واحدة، وتُعيد {batch_id, ingested_count}
   │
   ▼
الرد: { batch_id, ingested_count, key_version }
```

**ملاحظة تحفّظ متعمَّد:** دالة `admin_ingest_card_vault_batch` نفسها تسمح أيضاً لمالك الشبكة (`can_manage_network`) بجانب `platform_admin`. هذه الدالة (`encrypt-cards`) تتعمّد التقييد لـ `platform_admin` فقط في هذه المرحلة، تماشياً مع نطاق هذه المهمة ("admin-only"). توسيعها لتشمل ملاك الشبكات (تمكينهم من تحميل كروت شبكاتهم) قرار منتج منفصل يتطلب مراجعة (هل يُسمح لمالك الشبكة برؤية/كتابة نص صريح لكروته؟) — غير مغطى هنا.

---

## 4. تدفق كشف العميل (Customer Reveal)

```
العميل الذي أتم عملية شراء (JWT: مستخدم مصادَق)
   │
   ▼
POST /functions/v1/reveal-card
   { purchase_id }
   │
   └─ استدعاء reveal_purchase_card_secret(purchase_id) بتوكن المستخدم نفسه
        (لا مغلّف ولا معرّف كرت يُقبل من العميل مطلقاً — هذا الاستدعاء
        هو حدود التفويض الوحيدة)
        │
        ├─ الدالة (RPC) تتحقق: auth.uid() = purchase_records.user_id
        │      → غير ذلك: NOT_FOUND (لا تُفصح حتى بوجود عملية لغير صاحبها)
        ├─ تتحقق: purchase_records.status = 'completed'
        │      → غير ذلك: INVALID_STATE
        ├─ تتحقق: card_vault.state = 'sold' (وليست quarantined/invalidated)
        │      → غير ذلك: CARD_BLOCKED / INVALID_CARD_STATE
        ├─ تُسجّل first_revealed_at / dispute_deadline (+30 دقيقة) / reveal_count
        ├─ تكتب حدث تدقيق CARD_REVEALED عبر record_audit_event (BR-AUDIT-001)
        └─ تُعيد {purchase_id, status, key_version, ciphertext_b64, nonce, auth_tag_b64}
   │
   ├─ تحميل مفتاح AES بحسب key_version المُعاد
   │      → غير موجود: 503 SERVICE_UNAVAILABLE
   │
   └─ aes256GcmDecrypt(...) → النص الصريح
          فشل الفك (تلاعب/مفتاح خاطئ): 500 DECRYPTION_FAILED
          (لا تُسجَّل أي مادة نص صريح أو مشفّر في السجلات في الحالتين)
   │
   ▼
الرد: { purchase_id, status, plaintext_pin }  ← لصاحب الشراء فقط
```

---

## 5. مطابقة ضوابط الأمان والخصوصية

مطابقةً لتصنيف `CARD_SECRET` في `docs/NETYEMEN-DATA-CLASSIFICATION-AND-PRIVACY-01.md` ("ممنوع في السجلات إطلاقاً" / "يُفصح حصراً للمشتري"):

* **لا تسجيل مطلقاً (`STRICTLY FORBIDDEN IN LOGS`):** كلا الدالتين (`encrypt-cards`, `reveal-card`) لا تكتبان `console.log`/`console.error` لأي نص صريح أو حتى مغلّف مشفّر — فقط رموز الأخطاء وفئتها (`ENCRYPTION_FAILED`, `DECRYPTION_FAILED`, ...) دون تفاصيل المحتوى.
* **`BR-CARD-005` (عقد الكشف للمشتري حصراً):** مطبَّق بالكامل داخل `reveal_purchase_card_secret` نفسها؛ `reveal-card` لا تكرر هذا المنطق ولا تلتف حوله — تستدعي RPC بتوكن الطالب نفسه فقط.
* **`BR-SUPPORT-002` (كشف مقيّد داخل تذكرة دعم):** خارج نطاق هذا المستند حالياً — `reveal_purchase_card_secret` تتحقق من ملكية الشراء فقط، لا من سياق تذكرة دعم. إن احتاج وكيل الدعم كشف كرت نيابة عن عميل داخل تذكرة، يلزم إجراء RPC/Edge منفصل بمنطق تفويض مختلف (ليس ضمن نطاق `CARD-ENC-DESIGN`) — يُرصد هنا كعمل مستقبلي.
* **`BR-ADMIN-002` (منع تجاوز المسؤول لمنطق الشراء):** `encrypt-cards` تُدخل كروتاً بحالة `available` فقط (عبر `admin_ingest_card_vault_batch`)، ولا تستدعي أي مسار كشف أو شراء؛ `reveal-card` لا تحمل أي مسار يتيح للمسؤول انتحال هوية مشترٍ (يُستخدم توكن الطالب دائماً، لا مفتاح service-role).
* **التدقيق (`BR-AUDIT-001`):** كل كشف كرت يُسجَّل عبر `record_audit_event('CARD_REVEALED', ...)` **داخل** `reveal_purchase_card_secret`، أي قبل وصول التنفيذ لخطوة فك التشفير في Edge Function — التدقيق لا يعتمد على نجاح فك التشفير لاحقاً.
* **عزل مفتاح Service-Role:** لا تستخدم أي من الدالتين `SUPABASE_SERVICE_ROLE_KEY` — كلتاهما تعملان بتوكن المستخدم المستدعي المُمرَّر عبر ترويسة `Authorization`، فتُسري عليهما كل قيود RLS/RPC العادية دون توسيع الصلاحيات.

---

## 6. خارج نطاق هذا المستند (`CARD-ENC-DEPLOY`)

المهام التالية بشرية بالكامل ومملوكة من Michael، ولا تُنفَّذ هنا:

* توليد المفتاح الفعلي (32 بايت عشوائية) لكل `key_version`.
* رفعه إلى أسرار Supabase (`supabase secrets set CARD_MASTER_KEY_V1=...`).
* تنفيذ `supabase functions deploy encrypt-cards reveal-card`.
* إعداد `CARD_ACTIVE_KEY_VERSION` في بيئة الإنتاج.
* اختبار قبول E2E على بيئة معزولة قبل الإطلاق الفعلي.

---

## 7. الملفات المرجعية لهذا التصميم

| الملف | الدور |
|---|---|
| `supabase/functions/_shared/crypto.ts` | مساعدات AES-256-GCM المشتركة (تشفير/فك تشفير/تحميل مفتاح حسب الإصدار) |
| `supabase/functions/encrypt-cards/index.ts` | دالة الإدخال — تتحقق من `platform_admin`، تشفّر، تستدعي `admin_ingest_card_vault_batch` |
| `supabase/functions/reveal-card/index.ts` | دالة الكشف — تستدعي `reveal_purchase_card_secret`، تفك التشفير، تُعيد النص الصريح للمشتري فقط |
