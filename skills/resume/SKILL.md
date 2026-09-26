---
name: resume
description: Kaldığın yerden devam et. Yeni bir oturumun başında kullanıcı "devam", "kaldığın yerden", "resume", "nerede kalmıştık" dediğinde kullan. docs/STATE.md'yi okur, gerekirse ilgili planın durum kutusunu açar, anlaşılanı kullanıcıya doğrulatır.
---

# Resume: kaldığın yerden devam

## Adımlar
1. `docs/STATE.md`'yi oku (hook zaten eklediyse tekrar okuma).
2. STATE'teki aktif işin plan dosyasının **sadece üstteki durum kutusunu** oku. Tüm planı okuma.
3. Gerçekle karşılaştır, ucuz kontroller: `git status` / `git log -3` (varsa), STATE'te adı geçen dosyalar var mı?
   Çelişki varsa (örn. STATE "commit'lendi" diyor ama değişiklik duruyor) kullanıcıya söyle.
4. Kullanıcıya **en fazla 4 satır** yaz:
   - Anladığım: <aktif iş, nerede kalındı>
   - Sıradaki: <adım>
   - Bekleyen karar: <varsa>
   - "Doğru mu, başlayayım mı?"
5. Onay gelmeden iş yapma. Kullanıcı düzeltirse STATE.md'yi düzelt.

## İpuçları
- Bir araç/API ile çalışmadan önce `docs/LESSONS.md`'de o alanı grep ile ara (tamamını okuma).
- Ayrıntı gerekirse `docs/logs/`'ta grep yap. Log'u baştan sona okuma.
