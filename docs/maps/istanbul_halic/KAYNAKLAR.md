# Kaynaklar — sürüm 4

## Coğrafi veri

26 Eylül 2026'da alınan OpenStreetMap alanı:
28.952–28.984° D, 41.013–41.037° K. Dört OSM API parçası nesne
kimliği/sürümüyle birleştirilmiştir. İstek URL'leri ve nesne sayımları
`source/osm_v4_metadata.json` içindedir.

© OpenStreetMap contributors. Ham veri `source/istanbul_extended_v4.osm`
dosyasındadır. Türetilen bina/cami listeleri aynı veri kaynağına dayanır.

- https://www.openstreetmap.org/copyright
- https://opendatacommons.org/licenses/odbl/1-0/

Cami adları için ek kontrol kaynağı: Beyoğlu Müftülüğü cami listesi.
https://istanbul.diyanet.gov.tr/beyoglu/sayfalar/contentdetail.aspx?ContentId=117&MenuCategory=Kurumsal

Yeşillik güncellemesinde aynı OSM dosyasındaki park, bahçe, çim, orman,
mezarlık ve dinî alan sınırları ile tekil ağaç noktaları kullanılmıştır.
Yeni ağaç/çalı dağılımları ve küçük kıyı/yol kenarı bitki adaları, açık geçişleri
koruyan özgün oyun çevresi düzenlemeleridir. Ağaç türü ve boyları temsilidir.

## Yükselti

Terrain Tiles, 26 Eylül 2026 tarihinde AWS açık veri dağıtımından alınmıştır.

- Veri kaydı: https://registry.opendata.aws/terrain-tiles/
- Format: https://github.com/tilezen/joerd/blob/master/docs/formats.md
- Kaynak/lisans atıfları: https://github.com/tilezen/joerd/blob/master/docs/attribution.md
- Dağıtım: https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png

Orijinal Terrarium PNG'leri ve kullanılan koordinatlar `source/elevation/`
içindedir. Terrarium çözümü: R × 256 + G + B / 256 − 32768 metre.

Arazi kaynak atıfları: SRTM and GMTED2010 terrain data courtesy of the
U.S. Geological Survey. Europe terrain data produced using Copernicus data
and information funded by the European Union — EU-DEM layers. Global
ETOPO1 terrain data: U.S. National Oceanic and Atmospheric Administration.

Karışık veri sağlayıcısındaki her pikselin kaynak bileşeni ayrıca belirlenmemiştir.
Kullanılan yüksekliklere yumuşatma ve kıyı kotu düzeltmesi uygulanmıştır; bu
uyarlamalar veri sağlayıcıları tarafından onaylanmış ölçümler değildir.

## Fotoğraf ve mimari referanslar

- Süleymaniye: https://visit.istanbul/suleymaniye-mosque
- Yeni Cami: https://www.kulturportali.gov.tr/turkiye/istanbul/gezilecekyer/yeni-cami-1
- Yeni Cami mimari ölçü/şema: https://www.fatih.bel.tr/tr/main/pages/fatihte-bulunan-selatin-camiler/272
- Rüstem Paşa: https://visit.istanbul/rustem-pasha-mosque
- Kılıç Ali Paşa dış cephe: https://www.routard.com/photos/istanbul/1375574-mosquee_kilic_ali_pasa.htm
- Kılıç Ali Paşa: https://visit.istanbul/kilic-ali-pasha-mosque
- Arap Camii: https://visit.istanbul/arap-mosque
- Bereketzade: https://dijitalistanbul.org/bereketzade-camii
- Kalenderhane: https://visit.istanbul/kalenderhane-mosque
- Galata/Karaköy cephe dili: https://kulturenvanteri.com/yer/kamondo-apartmani/
- Galata Köprüsü: https://commons.wikimedia.org/wiki/Galata_Bridge

Temel fotoğraf gözlemleri: kubbe kasnakları ve dilimleri, kademeli örtü,
şerefeli ince minareler, sütunlu avlu, taş kemer çerçeveleri, Arap Camii'nin
kare tuğla kulesi, mahalle yapılarında demir balkon ve pencere silmeleri.
Her yapının birebir tüm cephelerinin yeniden kurulduğu iddia edilmez.
Tekil model profilleri ve temsili modeller cami envanterinde ayırt edilir.

Referans fotoğraflar dağıtılan pakete alınmamış ve doku olarak kullanılmamıştır.

## Teknik format

- https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html
- https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html

Bu çalışma için yazılmış Python/GDScript kodları ve bağımsız özgün dekor
geometrisi CC0 1.0 kapsamında sunulur:
https://creativecommons.org/publicdomain/zero/1.0/
Bu ifade OSM ve yükselti verilerinin kendi şartlarını değiştirmez.
Godot ve Blender programları pakete dahil değildir.

## Haliç Metro Köprüsü ve sokak detayları — sürüm 4

Köprü referansı: İstcon İnşaat proje sayfası ve buradaki yapım/tamamlanmış yapı fotoğrafları.
https://www.istconinsaat.com.tr/tr/projelerimiz/istanbul-metrosu-halic-metro-gecis-koprusu-yapim-isi

Ana açıklık 180 m, iki pilonun deniz yüzeyinden tepe yüksekliği 65 m;
merkezde istasyon, yanal cam kanopiler ve kıyı yaklaşım viyadükleri bulunur.
Bu ölçüler referans alınmış; köprü aksı OSM'deki M2 raylarının konumuna
göre yerleştirilmiştir. Tabliye kotu, küçük kesitler, kanopi panelleri ve
bağlantı merdivenleri oyun için yorumlanmıştır. Açılır bölüm kapalı ve statiktir.
Kastedilen yapı, Halıcıoğlu–Ayvansaray arasındaki karayolu Haliç Köprüsü değil,
ikili pilonları olan Haliç Metro Köprüsü'dür.

Sokak detayları: OSM `highway=traffic_signals`, `highway=crossing`,
`highway=street_lamp`, `lanes`, `oneway` ve yol sınıfları. Eksik aydınlatma
noktaları yol boyunca uygun aralıklarla üretilmiştir. Çizgiler, oklar,
sinyal direği ofsetleri ve renk fazları stilize, statik yorumlardır;
güncel bir trafik uygulama projesi veya tüm lambaların yerinde envanteri değildir.
