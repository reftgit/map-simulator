# İstanbul / Haliç — Genişletilmiş sürüm 4

Galata, Karaköy, Eminönü, Azapkapı, Süleymaniye, Kasımpaşa ve Unkapanı
çevresini kapsayan, yaklaşık **2,69 × 2,67 kilometrelik** 3D oyun çevresi. 1 Godot birimi 1 metredir.

Bu sürümde bina cephelerine pencere çerçeveleri, denizlikler, balkonlar,
kat silmeleri, girişler ve bacalar eklendi. Başlıca tarihî yapıların kubbe,
minare, avlu ve cephe biçimleri fotoğraf ve mimari kaynak referanslarıyla
çeşitlendirildi. **Araba ve tramvay modelleri yoktur.** Vapurlar statik dekordur.

Bu güncellemede parklar ve çim alanları daha belirgin yeşil yüzeylerle işlendi.
Geniş taçlı ağaçlar, servi biçimli ağaçlar, küçük sokak ağaçları ve çalı grupları
eklendi. Kıyıdaki uygun boşluklarda küçük bitki adaları, geniş yol kenarlarında
ağaç çukurları bulunur. Yollar, yaya yolları, bina girişleri ve taş döşeli cami
avluları bitki yerleşiminden çıkarılmıştır. Ağaç gövdelerinde basit çarpışma vardır.

Park/çim sınırları OSM'den gelir. Ek ağaç ve çalıların türleri, boyları ve
tekil yerleşimleri oyun için yorumlanmıştır; güncel bir ağaç envanteri değildir.
Bu sürümde toplam **5.477 ağaç**, **1.119 çalı** ve yaklaşık
**35,3 hektar** çim/bahçe yüzeyi vardır. Sayımlar ve yerleşim
kontrolleri `source/vegetation.json` dosyasındadır.

## Bu sürümdeki köprü ve sokak detayları

Haliç Metro Köprüsü fotoğraf referanslarıyla yeniden kurulmuştur: 180 metrelik
ana açıklık, iki adet 65 metrelik pilon, merkezi askı kabloları, çift ray,
yanal platformlar, kavisli istasyon kanopileri, alçak yaya yolları, bağlantı
merdivenleri ve yaklaşım viyadükleri. Kesitler ve tabliye kotları stilize
uyarlamalardır. Açılır bölüm kapalı ve statiktir; metro aracı yoktur.

Önceki bölge dahil bütün alanda yol sınıfına göre sokak lambaları, OSM kayıtlı
sinyal noktalarında trafik ışıkları, yaya geçitleri, dur çizgileri, şerit/kenar
çizgileri ve yön okları eklenmiştir. Yol boyları gerçek haritaya dayanır;
eksik genişlik ve şerit bilgileri yorumlanır. Direk yerleri ve işaretlemeler
birebir güncel trafik projesi değildir. Işık renkleri statiktir; trafik AI'sı
ve sinyal zamanlama sistemi yoktur. Lamba mercekleri ışık yayan malzemedir;
sahneye binlerce gerçek zamanlı noktasal ışık eklenmemiştir.

**4.008 sokak lambası**, **223 trafik ışığı** ve **160 yaya geçidi** oluşturulmuştur.
Köprü üstü lambalar ayrıca köprü geometrisinde yer alır.
`source/street_details.json` sayımları ve konumları; `source/bridge_metadata.json`
köprü boyutlarını ve referansı içerir.

## Godot'ta çalıştır

1. ZIP'i bir klasöre çıkar.
2. Godot 4.4 veya daha yeni Godot 4 sürümünde **Import / İçe aktar** seç.
3. `Godot/project.godot` dosyasını aç, modelin ilk içe aktarımını bekle.
4. **F5** ile çalıştır.

| Tuş | İşlev |
|---|---|
| Sağ fare tuşu | Fareyi yakala, çevreye bak |
| WASD | Hareket |
| Shift | Hızlan |
| Q / E | Uçuşta alçal / yüksel |
| F | Yürüyüş / uçuş; yürüyüş köprüde başlar |
| Space | Zıpla |
| 1 / 2 / 3 / 4 / 5 | Galata / Köprü / Eminönü / Genel / Süleymaniye |
| 6 / 7 / 8 | Haliç Metro Köprüsü / Sokak ayrıntısı / Kasımpaşa |
| M | Cami adlarını göster / gizle |
| R | Köprüye dön |
| H | Arayüzü göster / gizle |
| Esc | Fareyi serbest bırak |

Suya düşen karakter başlangıca döner. Uçuş modu çarpışmaları dikkate almaz.

## Camilerin kapsamı

Seçilen sınırlar içindeki OSM verisinde bina izi bulunan ve `building=mosque` veya
`amenity=place_of_worship` + `religion=muslim` olarak kayıtlı **125 ibadet yapısı**
modellenmiştir. Bunlar cami, mescit ve ibadet işlevi kaydedilmiş medrese yapısını
kapsar. Adları, OSM kimlikleri ve kullanılan model tipleri `CAMI_ENVANTERI.md`
ve `source/mosques.json` içindedir.

Süleymaniye, Yeni Cami, Kılıç Ali Paşa, Rüstem Paşa, Arap Camii ve başka
önemli yapılarda ayrı mimari profiller kullanılır. Diğer mahalle camileri ve
mescitleri gerçek bina izleri üzerinde temsili çatı/minare düzenleriyle
oluşturulmuştur. Her caminin her cephesi fotoğraflardan birebir çıkarılmış
değildir. OSM'de bulunmayan yapılar için eksiksizlik garantisi verilmez.

## Arazi ve coğrafi doğruluk

- Yollar, bina izleri, kıyı çizgisi ve yeşil alanlar OSM'den gelir.
- Yükseklikler Mapzen/Tilezen **Terrain Tiles DEM** verisinden örneklenir.
  Oyun arazisi 8 metrelik hücrelerle oluşturulur. Bu hücre aralığı, kaynak
  verinin ölçüm çözünürlüğü anlamına gelmez.
- DEM, küçük yüzey artefaktlarını azaltmak için hafifçe yumuşatılır. Kıyı
  yakınındaki kotlar, su/harita uyuşmazlığını önlemek için 1,5 metre rıhtım
  kotuna geçiş yapacak şekilde düzeltilir.
- Arazi kotları yaklaşık 1,5–88 metre aralığındadır. Galata ve Süleymaniye
  yükseltileri ile kıyı yamaçları geometride bulunur. Düşey ölçek abartılmamıştır.
- Bina yüksekliklerinin çoğu OSM'de eksik olduğu için tahminidir. Cephe
  süslemeleri, yapı oranları ve köprü ayrıntıları stilize yorumlardır.
- Bu çalışma fotogrametri, mimari rölöve veya ölçme projesi değildir.
- İç mekân, görev, NPC, sürüş sistemi ve AI navigasyonu içermez.

Yerel başlangıç **28.975° D, 41.023° K**; sınırlar **28.952–28.984° D,
41.013–41.037° K**. Godot/glTF eksenleri: **+X doğu, +Y yukarı, -Z kuzey**.

## Dosyalar ve düzenleme

- `Godot/assets/istanbul_halic.glb`: bağımsız ana model ve gömülü renk/malzemeler.
- `Godot/main.tscn`: ışıklar, su, arayüz ve gezinti kontrolü.
- `Godot/assets/map_metadata.json`: cami etiketleri ve başlangıç konumu.
- `Istanbul_Halic.blend`: aynı modelin düzenlenebilir Blender sahnesi.
- `previews/`: genel görünüm, Galata, Eminönü, Süleymaniye, arazi, metro köprüsü, sokak ve Kasımpaşa.
- `source/`: üretim betikleri, OSM/DEM verileri ve doğrulama kayıtları.

Bina, zemin, yol, dekor ve cami detayları ayrı düğümlerde bulunur. Şehir
geometrisi 150 metrelik parçalara ayrılır. `-col` son eki Godot'ta statik
çarpışma üretir. Küçük dekor ve su için çarpışma oluşturulmaz.

Sahne yaklaşık 7,07 milyon üçgen ve 9.001 bina içerir; ilk sürümden daha ağırdır.
Godot içe aktarımında otomatik LOD üretimi açıktır. Bu sahne doğrudan mobil
cihazlar için optimize edilmiş bir harita olarak değerlendirilmemelidir. Kesin
geometri sayımları `source/statistics.json` içindedir. Godot 4.4.1 başsız
kontrolünde sahne, kamera, cami envanteri, araç yokluğu, sokak donatıları ve iki köprüde yürüyüş
kontrol edildi; cihazlara göre FPS ölçülmedi. Hedef donanımında gölge mesafesini,
LOD/çizim mesafelerini ve dekor ayrıntılarını oyunun ihtiyacına göre ayarla.

Önizlemeler GLB geometrisinden Blender ile alınmıştır. Oyun ışığı ve su
malzemesi, önizleme ışıklarından farklıdır. Blender'daki
`Preview_Backdrop-noimp` yalnızca stüdyo zemini olarak kullanılır.

## Kaynakları koru

Coğrafi veri: **© OpenStreetMap contributors — ODbL 1.0**.
Arazi: **Mapzen/Tilezen Terrain Tiles; USGS ve Avrupa EU-DEM kaynak atıfları**.
Ayrıntılı bağlantılar ve kaynak notları `KAYNAKLAR.md` içindedir.
Fotoğraflar referans olarak kullanılmıştır; doku olarak uygulanmamış veya
pakete kopyalanmamıştır. Yayınlarken ilgili veri atıflarını koru.

## Yeniden üret

Haritayı Godot'ta açmak için Python veya Blender gerekmez. Geometriyi yeniden
oluşturmak istersen paket kökünde:

```bash
python -m pip install numpy shapely mapbox-earcut pillow
python source/build_map.py
```

Betik paket içindeki OSM ve DEM verileriyle çevrimdışı çalışır; ana GLB'yi
üzerine yazar. Kendi model düzenlemelerini önce ayrı bir kopyada sakla.

Blender 4.5 ile önizlemeleri ve düzenlenebilir sahneyi yeniden üretmek:

```bash
blender --background --python source/render_map.py
```

Godot denetimi:

```bash
godot --headless --editor --path Godot --import
godot --headless --path Godot --script ../source/validate_scene.gd
```
