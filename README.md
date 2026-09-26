# Claude Context Kit: oturumlar arası bağlam sistemi

Amaç: Context dolduğunda, oturum kapandığında ya da başka bir amaçla yeni oturum açıldığında Claude'un
yapılanları **unutmaması**, **yanlış anlamaması** ve **eskimiş bilgiyle iş yapmaması**. Bunu yaparken context'i
şişirmemek ve Claude'un esnekliğini öldürmemek.

Proje bağımsızdır, her projeye kurulabilir. Bu klasör bir öneri ve deneme alanıdır. Hiçbir projeye henüz uygulanmadı.

---

## 1. Sorun neden oluyor?

| Sorun | Sebep |
|---|---|
| Unutma | Bilgi sadece konuşmada duruyor. Context sıkışınca ya da oturum kapanınca gidiyor. |
| Yanlış anlama | Dosyada eskimiş bilgi var ve güncel bilgiyle karışıyor (örn. artık geçersiz bir "sıradaki adım" talimatı hâlâ duruyor). |
| Context şişmesi | Her şey tek dosyada, her oturumda baştan sona okunuyor. |
| Esneklik kaybı | Dokümanlar "ne yapılacak"ı adım adım dikte ediyor, "neden"i söylemiyor. Durum değişince Claude eski tarife uyuyor. |

Model uzun context'te dikkatini dağıtır ("context rot"). Anthropic'in önerisi: notları context **dışında** tutup
**sadece gerektiği an** geri çağırmak (structured note-taking + just-in-time retrieval). Kaynaklar sonda.

---

## 2. Çözüm: 3 katman + devir teslim notu

Senin "genel md + çok detaylı md, gerekirse baksın" fikrin doğru yön. Eksik olan iki şey var: **katmanlar arası yönlendirme**
(nerede ne var haritası) ve **tek bir güncel durum dosyası** (devir teslim).

```
Katman 0: HER OTURUM otomatik yüklenir      (bütçe: toplam ~8 KB / ~3k token)
  CLAUDE.md          kurallar + "harita" (hangi bilgi hangi dosyada)
  docs/STATE.md      DEVİR TESLİM: şu an ne yapılıyor, sıradaki adım, açık sorular   (<= 40 satır)

Katman 1: İhtiyaç olunca okunur              (dosya başına <= ~150 satır)
  docs/PROJECT.md    projenin "neden"i, nadiren değişir
  docs/DECISIONS.md  kararlar: tarih | karar | neden     (tek satır)
  docs/LESSONS.md    teknik tuzaklar: "X yapınca Y oluyor, çözüm Z"   (tek satır)
  docs/plans/<iş>.md iş planı: EN ÜSTTE 10 satırlık durum kutusu, sonra adımlar

Katman 2: Arşiv, nadiren okunur (grep ile aranır)
  docs/logs/<iş>.md  adım adım ayrıntılı sonuç günlüğü (sayılar, dosya yolları, denenen/bırakılan)
  git geçmişi        kodun ve asset'lerin tam geçmişi
  reference/         ham kaynaklar (PDF, GDD, veri)
```

**Kural: Bir bilgi tek yerde yaşar.** Diğer yerler ona sadece bağlantı verir. Böylece iki dosya çelişmez.

### Neden bu, "her şeyi çok detaylı yaz"dan iyi?
- Claude her oturumda sadece ~3k token okur, geri kalanı haritadan bulup **ihtiyaç olduğunda** açar. Context yavaş dolar.
- Ayrıntı kaybolmaz, sadece Katman 2'ye taşınır.
- "Şu an neredeyiz" sorusunun tek cevabı `STATE.md`'dir. Eski plan metni kafa karıştırmaz.

### Esneklik nasıl korunur?
- Dokümanlar **karar + neden + sınır** yazar, adım adım tarif yazmaz.
  Kötü: "Önbellek süresini 5 dk yap." İyi: "API kota aşımı yaşandı, önbellek süresi 5 dk yapıldı (karar YYYY-MM-DD). Kota sorunu çözülürse düşürülebilir."
- CLAUDE.md'de açık kural: "Doküman ile gerçek durum çelişirse gerçeğe bak (kod, sahne, git) ve çelişkiyi söyle. Körü körüne uyma."
- Kararlar değiştirilebilir, ama kullanıcıya sorulup `DECISIONS.md`'ye yeni satır olarak yazılır. Eski satır silinmez, "yerine geçti" diye işaretlenir.

---

## 3. İş akışı (ritüeller)

| Ne zaman | Ne olur | Nasıl |
|---|---|---|
| Oturum başı | Claude `STATE.md`'yi okur, **3 satırda anladığını söyler**, kullanıcı onaylar ya da düzeltir | SessionStart hook otomatik enjekte eder + `resume` skill |
| İş sırasında | Adım bitince plan kutucuğu + log satırı. Yeni tuzak öğrenilince LESSONS'a 1 satır | Alışkanlık, CLAUDE.md kuralı |
| Context ~%70 dolunca ya da oturum biterken | "devret" / `/handoff` → STATE, LESSONS, plan kutusu, ROADMAP güncellenir | `handoff` skill |
| Compaction sonrası | STATE.md otomatik yeniden enjekte edilir, özet eksik kalsa bile yol kaybolmaz | SessionStart hook (source: compact) |
| Farklı amaçla yeni oturum | Sadece Katman 0 yüklenir. İlgisiz planlar okunmaz | Harita sayesinde |
| Ayda bir / dosya bütçeyi aşınca | Eskiyen satırlar log'a/arşive taşınır | `doc-hygiene` skill |

"Devret" en kritik adım. Context dolmadan **önce** yapılmalı, çünkü compaction sonrası Claude detayları zaten kaybetmiş olur.

---

## 4. Plugin yapısı (`context-kit`)

```
.claude-plugin/plugin.json      plugin tanımı (ad: context-kit)
skills/                         Claude bu skill'leri tetikleyici kelimelerle kendisi çağırır
  context-setup/SKILL.md        "bağlam sistemini kur": projeye STATE/LESSONS/DECISIONS + CLAUDE.md haritası
  context-setup/templates/      CLAUDE, STATE, LESSONS, DECISIONS, PLAN şablonları
  handoff/SKILL.md              "devret": oturum sonu güncellemesi
  resume/SKILL.md               "devam / kaldığın yerden": oturum başı
  doc-hygiene/SKILL.md          "dokümanları temizle": bütçe kontrolü ve arşivleme
hooks/hooks.json                SessionStart: docs/STATE.md'yi otomatik ekler (startup, resume, clear, compact)
scripts/inject-state.sh         hook betiği (STATE.md yoksa sessizce çıkar)
README.md                       bu dosya
```

## 5. Deneme ve kurulum (henüz yapılmadı)
1. **Doğrula:** `claude plugin validate D:\claude-context-kit`
2. **Kurmadan dene (sadece o oturum):** `claude --plugin-dir D:\claude-context-kit`
   - Test: yeni oturumda STATE.md içeriği geliyor mu? "devret" deyince handoff çalışıyor mu?
3. **Kalıcı kurulum:** yerel bir marketplace ile (`/plugin` komutları). Kesin adımlar kurulum sırasında belgeden doğrulanır.
4. **Kapatma / kaldırma:** `/plugin` menüsünden devre dışı bırakılır. Dosyalara dokunmak gerekmez.
5. **Mevcut bir projeyi geçirmek:** o projede "bağlam sistemini kur" de. `context-setup` önce inceler, plan sunar, onay ister.

## 6. Riskler ve dürüst notlar
- **Güncellenmeyen doküman, dokümansızlıktan kötüdür.** Sistem ancak "devret" alışkanlığıyla çalışır. Skill ve hook bunu kolaylaştırır, garanti etmez.
- Hook'lar Claude Code sürümüne bağlıdır. `SessionStart` ve `source: compact` davranışı kurulumdan sonra bir kez test edilmeli.
- Otomatik "auto memory" (`~/.claude/projects/.../memory`) sadece kişisel tercihler için kalmalı. Proje bilgisi `docs/`'ta durmalı, çünkü görünür, düzeltilebilir ve git'e girebilir.

## Kaynaklar
- Anthropic, Effective context engineering for AI agents: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- Claude Cookbook, context engineering (memory, compaction, tool clearing): https://platform.claude.com/cookbook/tool-use-context-engineering-context-engineering-tools
- Cline Memory Bank (kısa/uzun süreli hafıza ayrımı): https://docs.cline.bot/best-practices/memory-bank
