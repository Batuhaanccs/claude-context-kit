---
name: handoff
description: Oturumu devret. Kullanıcı "devret", "handoff", "oturumu kapat", "context doluyor", "kaydet ve bitir" dediğinde ya da context belirgin şekilde dolduğunda kullan. Projenin docs/STATE.md, LESSONS.md, plan durum kutusu ve roadmap dosyalarını bir sonraki oturum sıfırdan devam edebilecek şekilde günceller.
---

# Handoff: oturumu devret

Amaç: bu oturumdaki bilgi, context kapansa bile kaybolmasın. Bir sonraki Claude sadece Katman 0'ı (CLAUDE.md + STATE.md)
okuyup doğru yerden devam edebilmeli.

## Adımlar
1. **Durumu topla (dosya okuma değil, bu konuşmadan):** aktif iş, son biten adım, yarım kalan iş, çalışma alanı durumu
   (git status varsa bak), kullanıcıdan bekleyen kararlar, bu oturumda öğrenilen teknik tuzaklar.
2. **docs/STATE.md'yi yeniden yaz** (şablon: `context-setup` skill'indeki `templates/STATE.template.md`). Dosya yoksa önce `context-setup` öner. Kurallar:
   - <= 40 satır. Geçmiş değil, şimdi.
   - "Sıradaki adım" tek ve somut olsun ("Adım 11: ağaç kaynağı kararı kullanıcıda" gibi).
   - Tarih ve saat yaz.
3. **docs/LESSONS.md'ye** bu oturumda öğrenilen, tekrar edebilecek tuzakları ekle (tek satır: belirti → sebep → çözüm).
   Zaten yazılı olanı tekrar yazma.
4. **Plan dosyasının üstündeki durum kutusunu** güncelle. Adım kutucukları doğru mu kontrol et.
   Eskimiş metin varsa (artık geçerli olmayan talimat) sil ya da "(eski)" diye işaretle.
5. **Ayrıntılı sonuçları** (sayılar, dosya yolları, denenenler) `docs/logs/<iş>.md`'ye ekle. Plana değil.
6. **Proje roadmap'i varsa** "aktif" satırını STATE ile tutarlı yap.
7. **Bütçe kontrolü:** STATE > 40 satır, LESSONS > 60 satır ya da plan kutusu > 12 satır ise fazlasını log'a/arşive taşı.
8. Kullanıcıya **5 satırı geçmeyen** bir özet ver: neyi güncellediğini ve yeni oturumda ne yazması gerektiğini
   (genelde sadece "devam" ya da "kaldığın yerden").

## Yapma
- Kod, sahne, asset değiştirme. Bu skill sadece doküman günceller.
- Commit atma (kullanıcı ayrıca isterse at).
- Konuşmayı olduğu gibi kopyalama. Karar ve durum yaz, sohbet değil.
