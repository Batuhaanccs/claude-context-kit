---
name: doc-hygiene
description: Proje dokümanlarını temizle ve bütçede tut. Kullanıcı "dokümanları temizle", "md'ler şişti", "doc hygiene" dediğinde ya da STATE/LESSONS/plan dosyaları bütçeyi aştığında kullan. Eskiyen bilgiyi arşive taşır, çelişkileri bulur, hiçbir bilgiyi silmez.
---

# Doc hygiene: dokümanları bütçede tut

## Bütçeler
| Dosya | Sınır | Aşarsa |
|---|---|---|
| CLAUDE.md | ~80 satır | Uzun açıklamaları ayrı dosyaya taşı, bağlantı bırak |
| docs/STATE.md | 40 satır | Geçmişe ait satırlar → `docs/logs/<iş>.md` |
| docs/LESSONS.md | 60 satır | Artık geçerli olmayanlar (araç güncellendi vb.) → `docs/logs/lessons-archive.md` |
| Plan durum kutusu | 12 satır | Ayrıntı → log |
| Plan dosyası | ~150 satır | "Sonuç" paragrafları → log, planda tek satır + bağlantı |
| ROADMAP "Bitti" | 30 satır | Eskiler silinir (git geçmişinde var) |

## Adımlar
1. `wc -l` ile boyutları ölç, bütçeyi aşanları listele.
2. Çelişki ara: aynı bilgi iki yerde farklı mı? (örn. plan "Adım 5 sıradaki" diyor, STATE "Adım 9"). Tek kaynağa indir.
3. Eskimiş talimatları bul (örn. tamamlanmış bir işin hâlâ "sıradaki" diye duran talimatı). "(eski)" işaretle ya da log'a taşı.
4. Taşı, silme. Taşınan her bölümün yerine tek satır bağlantı bırak.
5. Kullanıcıya önce/sonra satır sayısını ve taşınanların listesini göster. Onay almadan büyük taşıma yapma.
