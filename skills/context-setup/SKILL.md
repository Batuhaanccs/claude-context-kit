---
name: context-setup
description: Bir projeye oturumlar arası bağlam sistemini kur. Kullanıcı "bağlam sistemini kur", "context kit kur", "STATE/LESSONS oluştur", "bu projeyi context-kit'e geçir" dediğinde kullan. Şablonlardan docs/STATE.md, LESSONS.md, DECISIONS.md oluşturur, CLAUDE.md'ye ritüel ve harita ekler. Mevcut dosyaları ezmez.
---

# Context setup: projeye bağlam sistemini kur

Şablonlar bu skill'in yanındaki `templates/` klasöründe: CLAUDE, STATE, LESSONS, DECISIONS, PLAN.

## Adımlar
1. **Önce incele, dokunma:** projede CLAUDE.md, docs/, plan dosyaları, roadmap, auto memory var mı? Boyutlarını ölç (`wc -l`).
   Kullanıcıya kısa bir tablo göster: ne var, ne eksik, ne şişmiş, ne eskimiş.
2. **Plan öner, onay al.** Hangi dosyayı oluşturacağını, hangisini böleceğini, neyi taşıyacağını listele.
   Proje git değilse değiştirmeden önce `docs/` yedeği al (`docs_backup_YYYYMMDD`).
3. **Oluştur (sadece eksik olanları):**
   - `docs/STATE.md`: bu konuşmadan ve dosyalardan bugünkü gerçek durumu yaz (şablon: STATE.template.md).
   - `docs/LESSONS.md`: bilinen teknik tuzaklar varsa ekle, yoksa boş şablon.
   - `docs/DECISIONS.md`: dağınık kararları (roadmap, plan) tek tabloya topla. Eski yerde bağlantı bırak.
   - CLAUDE.md: "Oturum ritüeli" ve "Harita" bölümlerini ekle (CLAUDE.template.md). Var olan kuralları silme.
4. **Şişmiş plan dosyaları:** tepeye durum kutusu ekle (PLAN.template.md). Uzun "sonuç" paragraflarını
   `docs/logs/<iş>.md`'ye taşı, planda tek satır + bağlantı bırak. Eskimiş talimatları "(eski)" diye işaretle.
5. **Doğrula:** STATE <= 40 satır, harita her dosyaya doğru yolu veriyor, bilgi iki yerde tekrar etmiyor.
   Önce/sonra satır sayılarını göster.

## Yapma
- Kullanıcı onayı olmadan dosya bölme ya da taşıma.
- Kod, sahne, asset değişikliği.
- Auto memory'ye proje bilgisi yazma. Proje bilgisi docs/'ta durur.
