# <Proje adı>: Claude için notlar

<!-- KATMAN 0. Her oturum yüklenir. Bütçe: bu dosya <= ~80 satır. Ayrıntı buraya değil, haritadaki dosyalara. -->

## Oturum ritüeli
- Başta: `docs/STATE.md`'yi oku (hook otomatik ekleyebilir). Anladığını 3 satırda söyle, kullanıcı onaylamadan işe başlama.
- İş sırasında: adım bitince plandaki kutucuğu işaretle, sonucu `docs/logs/<iş>.md`'ye 1-3 satır yaz.
  Yeni bir teknik tuzak öğrenirsen `docs/LESSONS.md`'ye 1 satır ekle.
- Kullanıcı "devret" derse ya da context doluyorsa: `handoff` skill'ini çalıştır.

## Harita: bilgi nerede?
| Soru | Dosya | Ne zaman oku |
|---|---|---|
| Şu an ne yapılıyor, sıradaki adım? | `docs/STATE.md` | Her oturum başı |
| Proje neden var, hedef, kitle? | `docs/PROJECT.md` | Tasarım kararı verirken |
| Daha önce ne karar verildi? | `docs/DECISIONS.md` | Bir şeyi değiştirmeden önce |
| Bilinen teknik tuzaklar | `docs/LESSONS.md` | Bir araç/API ile iş yapmadan önce (grep) |
| Bir işin planı ve adımları | `docs/plans/<iş>.md` (üstteki durum kutusu) | O işe dokunurken |
| Ayrıntılı geçmiş, sayılar | `docs/logs/<iş>.md`, git log | Sadece gerekirse, grep ile |

## Doküman kuralları
- Bir bilgi tek yerde yaşar, diğer yerler bağlantı verir.
- Doküman gerçekle (kod, sahne, git) çelişirse gerçeğe bak, çelişkiyi kullanıcıya söyle, dokümanı düzelt.
- Kararlar "karar + neden" olarak yazılır, adım adım tarif olarak değil. Karar değişecekse kullanıcıya sor, yeni satır ekle.
- Bütçeler: STATE <= 40 satır, LESSONS <= 60 satır, plan durum kutusu <= 12 satır. Aşılırsa `doc-hygiene`.

## Proje kuralları
<!-- Kod standardı, git kuralları, yasaklar vs. Kısa madde. Uzun açıklama gerekiyorsa ayrı dosyaya bağlantı ver. -->
