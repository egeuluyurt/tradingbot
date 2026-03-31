//+------------------------------------------------------------------+
//|  CSignal.mqh — Sinyal Üretim Modülü                             |
//|  Görev: PRZ tabanlı AL/SAT/YOK sinyali üretir                   |
//|  Strateji: Fibonacci + RSI + MACD + Harmonik + Tetikleyici Mum  |
//+------------------------------------------------------------------+
#ifndef CSIGNAL_MQH
#define CSIGNAL_MQH

//--- Sinyal değerleri
enum ENUM_SIGNAL
{
   SIGNAL_YOK  = 0,   // Bekle, işlem yapma
   SIGNAL_AL   = 1,   // Alış sinyali
   SIGNAL_SAT  = -1   // Satış sinyali
};

//--- Tetikleyici mum türleri
enum ENUM_TETIKLEYICI
{
   TETIK_YOK       = 0,
   TETIK_PINBAR    = 1,
   TETIK_ENGULFING = 2,
   TETIK_HHHC_LLLC = 3
};

//====================================================================
//  CNewsFilter — MT5 Ekonomik Takvim API tabanlı haber filtresi
//  Sadece CALENDAR_IMPORTANCE_HIGH olayları dikkate alır.
//  Performans: Haber listesi günlük önbelleğe alınır; her tick'te
//  takvim veritabanı sorgulanmaz, yalnızca önbellek kontrol edilir.
//====================================================================
class CNewsFilter
{
private:
   //--- Önbellek: günün yüksek önemli haberlerinin zamanları
   datetime m_onbellekHaberler[];   // Önbelleğe alınan haber zamanları
   int      m_onbellekSayisi;       // Önbellekteki haber sayısı
   datetime m_onbellekGunu;         // Önbelleğin ait olduğu günün başlangıcı

   //--- Sembolle ilişkili para birimleri (dinamik filtreleme için)
   string   m_paraBirimleri[];      // Örn: ["EUR", "USD"]
   int      m_paraBirimiSayisi;

   //------------------------------------------------------------------
   // YARDIMCI: Bugünün başlangıç zamanını döndür (00:00:00)
   //------------------------------------------------------------------
   datetime BugunBaslangici()
   {
      MqlDateTime md;
      TimeToStruct(TimeCurrent(), md);
      md.hour = 0; md.min = 0; md.sec = 0;
      return StructToTime(md);
   }

   //------------------------------------------------------------------
   // YARDIMCI: Yarının başlangıç zamanını döndür
   //------------------------------------------------------------------
   datetime YarinBaslangici()
   {
      return BugunBaslangici() + 86400;
   }

   //------------------------------------------------------------------
   // SemboldenParaBirimleriCikar:
   // "EURUSD" → ["EUR", "USD"]
   // "XAUUSD" → ["XAU", "USD"]  (altın gibi özel semboller dahil)
   // Sembol 6 karakterden kısaysa tüm sembolü tek birim olarak ekle.
   //------------------------------------------------------------------
   void SemboldenParaBirimleriCikar(string sembol)
   {
      // Uzantıları temizle (.pro .m .r gibi)
      string temiz = sembol;
      string uzantilar[] = {".pro", ".m", ".r", ".c", ".i", ".PRO", ".M"};
      for(int i = 0; i < ArraySize(uzantilar); i++)
      {
         int pos = StringFind(temiz, uzantilar[i]);
         if(pos > 0) { temiz = StringSubstr(temiz, 0, pos); break; }
      }

      m_paraBirimiSayisi = 0;
      ArrayResize(m_paraBirimleri, 0);

      int uzunluk = StringLen(temiz);
      if(uzunluk >= 6)
      {
         // Standart forex çifti: ilk 3 + son 3 karakter
         string baz   = StringSubstr(temiz, 0, 3);
         string quote = StringSubstr(temiz, 3, 3);
         ArrayResize(m_paraBirimleri, 2);
         m_paraBirimleri[0]  = baz;
         m_paraBirimleri[1]  = quote;
         m_paraBirimiSayisi  = 2;
      }
      else if(uzunluk > 0)
      {
         ArrayResize(m_paraBirimleri, 1);
         m_paraBirimleri[0]  = temiz;
         m_paraBirimiSayisi  = 1;
      }
   }

   //------------------------------------------------------------------
   // HaberParaBirimiEslesiyor:
   // Takvim olayının para birimi, sembolümüzle ilişkili mi?
   // paraBirimiSayisi == 0 ise tüm haberleri kabul et (güvenli taraf).
   //------------------------------------------------------------------
   bool HaberParaBirimiEslesiyor(string haberParaBirimi)
   {
      if(m_paraBirimiSayisi == 0) return true;
      for(int i = 0; i < m_paraBirimiSayisi; i++)
         if(m_paraBirimleri[i] == haberParaBirimi) return true;
      return false;
   }

   //------------------------------------------------------------------
   // OnbellekGuncelle:
   // Yeni güne geçildiğinde (veya ilk çalıştırmada) bugünün
   // CALENDAR_IMPORTANCE_HIGH haberlerini takvimden çekip depolar.
   // Her tick'te değil, yalnızca gün değişiminde çağrılır.
   //------------------------------------------------------------------
   void OnbellekGuncelle()
   {
      datetime bugun = BugunBaslangici();

      // Aynı gün için önbellek zaten doluysa tekrar çekme
      if(m_onbellekGunu == bugun && m_onbellekSayisi >= 0) return;

      m_onbellekGunu   = bugun;
      m_onbellekSayisi = 0;
      ArrayResize(m_onbellekHaberler, 0);

      // MT5 Ekonomik Takvim API: bugün + yarın arası
      MqlCalendarValue haberDizisi[];
      datetime baslangic = bugun;
      datetime bitis     = YarinBaslangici();

      int adet = CalendarValueHistory(haberDizisi, baslangic, bitis);
      if(adet <= 0)
      {
         Print("CNewsFilter: Bugün için takvim verisi alınamadı (adet=", adet, ").");
         return;
      }

      for(int i = 0; i < adet; i++)
      {
         // Olayın detayını çek
         MqlCalendarEvent olay;
         if(!CalendarEventById(haberDizisi[i].event_id, olay)) continue;

         // Yalnızca yüksek önem derecesi
         if(olay.importance != CALENDAR_IMPORTANCE_HIGH) continue;

         // Para birimi filtresi (ülke bilgisinden para birimi alınamıyorsa kabul et)
         MqlCalendarCountry ulke;
         if(CalendarCountryById(olay.country_id, ulke))
         {
            if(!HaberParaBirimiEslesiyor(ulke.currency)) continue;
         }

         // Önbelleğe ekle
         ArrayResize(m_onbellekHaberler, m_onbellekSayisi + 1);
         m_onbellekHaberler[m_onbellekSayisi] = haberDizisi[i].time;
         m_onbellekSayisi++;
      }

      Print("CNewsFilter: ", m_onbellekSayisi,
            " yüksek önemli haber önbelleğe alındı — ",
            TimeToString(bugun, TIME_DATE));
   }

public:
   CNewsFilter()
      : m_onbellekSayisi(-1),   // -1: hiç güncellenmedi
        m_onbellekGunu(0),
        m_paraBirimiSayisi(0) {}

   //------------------------------------------------------------------
   // Init: Sembolü al, para birimlerini çıkar, ilk önbelleği doldur
   //------------------------------------------------------------------
   bool Init(string sembol)
   {
      SemboldenParaBirimleriCikar(sembol);
      OnbellekGuncelle();   // Başlangıçta bir kez doldur

      Print("CNewsFilter: MT5 Ekonomik Takvim filtresi başlatıldı — Sembol: ", sembol,
            " | Para birimleri: ",
            (m_paraBirimiSayisi > 0 ? m_paraBirimleri[0] : "?"),
            (m_paraBirimiSayisi > 1 ? "/" + m_paraBirimleri[1] : ""));
      return true;
   }

   //------------------------------------------------------------------
   // HaberZamaniMi: Şu an haber penceresinde miyiz?
   // pencereDakika: haberin kaç dakika öncesi/sonrası korunacak
   //
   // Performans notu: Bu fonksiyon her tick'te çağrılır.
   // Takvim veritabanı sorgusu yapılmaz — yalnızca önbellek taranır.
   // Gün değişiminde önbellek otomatik yenilenir (O(1) kontrol).
   //------------------------------------------------------------------
   bool HaberZamaniMi(datetime zaman, int pencereDakika = 30)
   {
      // Gün değişimi kontrolü — pahalı değil, sadece datetime karşılaştırması
      datetime bugun = BugunBaslangici();
      if(m_onbellekGunu != bugun) OnbellekGuncelle();

      int pencerekn = pencereDakika * 60;
      for(int i = 0; i < m_onbellekSayisi; i++)
      {
         if(MathAbs((long)(zaman - m_onbellekHaberler[i])) <= pencerekn)
            return true;
      }
      return false;
   }

   //------------------------------------------------------------------
   // Erişiciler
   //------------------------------------------------------------------
   int    OnbellekSayisi()    const { return m_onbellekSayisi;    }
   int    ParaBirimiSayisi()  const { return m_paraBirimiSayisi;  }
};

//====================================================================
//  CSignal — Ana Sinyal Sınıfı
//====================================================================
class CSignal
{
private:
   //--- İndikatör handle'ları
   int   m_rsiHandle;    // H1 RSI
   int   m_macdHandle;   // H1 MACD
   int   m_rsiH4Handle;  // H4 RSI (trend onayı)

   string          m_sembol;
   ENUM_TIMEFRAMES m_zaman;      // H1 ana zaman dilimi
   CNewsFilter     m_haberFilt;  // MT5 Ekonomik Takvim filtresi (değer tipi, pointer değil)
   datetime        m_sonBarZamani; // Son değerlendirilen H1 bar zamanı (yeni bar koruması)

   //------------------------------------------------------------------
   // YARDIMCI: Tek tampon değeri oku
   //------------------------------------------------------------------
   double IndikatorDeger(int handle, int tampon, int bar)
   {
      double arr[];
      ArraySetAsSeries(arr, true);
      if(CopyBuffer(handle, tampon, bar, 1, arr) <= 0) return EMPTY_VALUE;
      return arr[0];
   }

   //------------------------------------------------------------------
   // PRZ KOŞUL 1-2: Fibonacci Retracement/Extension kontrolü
   // Skalp aralığı: son 50 H1 barın yüksek/düşük aralığına göre
   // Gerçek uygulama: swing high/low'u bul, seviyeleri hesapla
   //------------------------------------------------------------------
   bool FibSeviyesiMi(double fiyat, bool alisSenaryosu)
   {
      // Swing high / swing low bul (son 50 bar)
      double yukari = iHigh(m_sembol, m_zaman, iHighest(m_sembol, m_zaman, MODE_HIGH, 50, 1));
      double asagi  = iLow (m_sembol, m_zaman, iLowest (m_sembol, m_zaman, MODE_LOW,  50, 1));
      double aralik = yukari - asagi;
      if(aralik < _Point) return false;

      double tolerans = aralik * 0.005; // %0.5 tolerans

      // Retracement seviyeleri (alış için asağıdan ölçülür)
      double ret618 = alisSenaryosu ? asagi  + aralik * 0.382 : yukari - aralik * 0.382;
      double ret786 = alisSenaryosu ? asagi  + aralik * 0.214 : yukari - aralik * 0.214;

      // Extension seviyeleri
      double ext1272 = alisSenaryosu ? asagi  - aralik * 0.272 : yukari + aralik * 0.272;
      double ext1618 = alisSenaryosu ? asagi  - aralik * 0.618 : yukari + aralik * 0.618;

      bool retFib  = (MathAbs(fiyat - ret618) <= tolerans || MathAbs(fiyat - ret786) <= tolerans);
      bool extFib  = (MathAbs(fiyat - ext1272) <= tolerans || MathAbs(fiyat - ext1618) <= tolerans);

      return (retFib || extFib);
   }

   //------------------------------------------------------------------
   // PRZ KOŞUL 3: Kırılan destek/direncin dönüşüm noktası (S/R flip)
   //------------------------------------------------------------------
   bool SRFlipMi(double fiyat, bool alisSenaryosu)
   {
      double tolerans = 20 * _Point;
      int aramaBar = 100;

      for(int i = 5; i < aramaBar; i++)
      {
         double yukari = iHigh(m_sembol, m_zaman, i);
         double asagi  = iLow (m_sembol, m_zaman, i);

         // Pivot yüksek: her iki taraftan da yüksek
         bool pivotYuksek = (yukari > iHigh(m_sembol, m_zaman, i+1) &&
                             yukari > iHigh(m_sembol, m_zaman, i+2) &&
                             yukari > iHigh(m_sembol, m_zaman, i-1) &&
                             yukari > iHigh(m_sembol, m_zaman, i-2));

         // Pivot düşük
         bool pivotDusuk = (asagi < iLow(m_sembol, m_zaman, i+1) &&
                            asagi < iLow(m_sembol, m_zaman, i+2) &&
                            asagi < iLow(m_sembol, m_zaman, i-1) &&
                            asagi < iLow(m_sembol, m_zaman, i-2));

         if(alisSenaryosu && pivotYuksek && MathAbs(fiyat - yukari) <= tolerans)
            return true;  // Eski direnç → destek'e dönüştü

         if(!alisSenaryosu && pivotDusuk && MathAbs(fiyat - asagi) <= tolerans)
            return true;  // Eski destek → direnç'e dönüştü
      }
      return false;
   }

   //------------------------------------------------------------------
   // PRZ KOŞUL 4: RSI aşırı alım/satım
   //------------------------------------------------------------------
   bool RSIAsiriMi(bool alisSenaryosu)
   {
      double rsi = IndikatorDeger(m_rsiHandle, 0, 1);
      if(rsi == EMPTY_VALUE) return false;

      return (alisSenaryosu ? rsi < 30.0 : rsi > 70.0);
   }

   //------------------------------------------------------------------
   // PRZ KOŞUL 5: MACD uyumsuzluğu (divergence)
   // Alış: fiyat yeni dip yapıyor ama MACD ana çizgisi yapmıyor
   // Satış: fiyat yeni tepe yapıyor ama MACD yapmıyor
   //------------------------------------------------------------------
   bool MACDUyumsuzlukMu(bool alisSenaryosu)
   {
      // Mevcut bar ve 10 bar öncesiyle karşılaştır
      double fiyatSon  = iClose(m_sembol, m_zaman, 1);
      double fiyatOnce = iClose(m_sembol, m_zaman, 10);

      double macdSon   = IndikatorDeger(m_macdHandle, 0, 1);   // Ana çizgi
      double macdOnce  = IndikatorDeger(m_macdHandle, 0, 10);

      if(macdSon == EMPTY_VALUE || macdOnce == EMPTY_VALUE) return false;

      if(alisSenaryosu)
         return (fiyatSon < fiyatOnce && macdSon > macdOnce);  // Fiyat yeni dip, MACD yapmıyor
      else
         return (fiyatSon > fiyatOnce && macdSon < macdOnce);  // Fiyat yeni tepe, MACD yapmıyor
   }

   //------------------------------------------------------------------
   // PRZ KOŞUL 6: Harmonik formasyon — Bat modeli D noktası
   // XA hareketinin %88.6'sı (basit: swing hareketine göre)
   //------------------------------------------------------------------
   bool HarmonikBatMi(double fiyat, bool alisSenaryosu)
   {
      double yukari = iHigh(m_sembol, m_zaman, iHighest(m_sembol, m_zaman, MODE_HIGH, 100, 1));
      double asagi  = iLow (m_sembol, m_zaman, iLowest (m_sembol, m_zaman, MODE_LOW,  100, 1));
      double aralik = yukari - asagi;
      if(aralik < _Point) return false;

      double d886  = alisSenaryosu ? yukari - aralik * 0.886 : asagi + aralik * 0.886;
      double tolerans = aralik * 0.005;

      return (MathAbs(fiyat - d886) <= tolerans);
   }

   //------------------------------------------------------------------
   // PRZ DOĞRULAMA: En az 5 koşul sağlanmalı
   //------------------------------------------------------------------
   int PRZPuanHesapla(double fiyat, bool alisSenaryosu)
   {
      int puan = 0;
      if(FibSeviyesiMi   (fiyat, alisSenaryosu)) puan++;
      if(SRFlipMi        (fiyat, alisSenaryosu)) puan++;
      if(RSIAsiriMi      (alisSenaryosu))         puan++;
      if(MACDUyumsuzlukMu(alisSenaryosu))         puan++;
      if(HarmonikBatMi   (fiyat, alisSenaryosu)) puan++;
      return puan;
   }

   //------------------------------------------------------------------
   // TETİKLEYİCİ MUM: Pinbar, Engulfing veya HHHC/LLLC
   //------------------------------------------------------------------
   ENUM_TETIKLEYICI TetikleyiciMumKontrol(bool alisSenaryosu)
   {
      double acilis1 = iOpen (m_sembol, m_zaman, 1);
      double kapanis1= iClose(m_sembol, m_zaman, 1);
      double yukari1 = iHigh (m_sembol, m_zaman, 1);
      double asagi1  = iLow  (m_sembol, m_zaman, 1);

      double acilis2 = iOpen (m_sembol, m_zaman, 2);
      double kapanis2= iClose(m_sembol, m_zaman, 2);
      double yukari2 = iHigh (m_sembol, m_zaman, 2);
      double asagi2  = iLow  (m_sembol, m_zaman, 2);

      double govde1 = MathAbs(kapanis1 - acilis1);
      double aralik1= yukari1 - asagi1;
      if(aralik1 < _Point) return TETIK_YOK;

      // --- Pinbar ---
      // Alış pinbar: uzun alt fitil (aralığın >%60), küçük gövde, üstte kapanış
      if(alisSenaryosu)
      {
         double altFitil = MathMin(acilis1, kapanis1) - asagi1;
         if(altFitil > aralik1 * 0.6 && govde1 < aralik1 * 0.3)
            return TETIK_PINBAR;
      }
      else
      {
         double ustFitil = yukari1 - MathMax(acilis1, kapanis1);
         if(ustFitil > aralik1 * 0.6 && govde1 < aralik1 * 0.3)
            return TETIK_PINBAR;
      }

      // --- Engulfing ---
      // Alış engulfing: önceki mum bearish, şimdiki bullish ve tamamen yutar
      if(alisSenaryosu)
      {
         bool oncekiBearish = kapanis2 < acilis2;
         bool simdikiBullish= kapanis1 > acilis1;
         if(oncekiBearish && simdikiBullish &&
            kapanis1 > acilis2 && acilis1 < kapanis2)
            return TETIK_ENGULFING;
      }
      else
      {
         bool oncekiBullish  = kapanis2 > acilis2;
         bool simdikiBearish = kapanis1 < acilis1;
         if(oncekiBullish && simdikiBearish &&
            kapanis1 < acilis2 && acilis1 > kapanis2)
            return TETIK_ENGULFING;
      }

      // --- HHHC (alış) / LLLC (satış) ---
      if(alisSenaryosu)
      {
         // Higher High Higher Close
         if(yukari1 > yukari2 && kapanis1 > kapanis2 && kapanis1 > acilis1)
            return TETIK_HHHC_LLLC;
      }
      else
      {
         // Lower Low Lower Close
         if(asagi1 < asagi2 && kapanis1 < kapanis2 && kapanis1 < acilis1)
            return TETIK_HHHC_LLLC;
      }

      return TETIK_YOK;
   }

   //------------------------------------------------------------------
   // YASAKLI ZAMAN 1: Gece 00:00 mum geçişi
   //------------------------------------------------------------------
   bool GeceyarisiBariMi()
   {
      datetime barZamani = iTime(m_sembol, m_zaman, 1);
      MqlDateTime mt;
      TimeToStruct(barZamani, mt);
      // H1 çerçevesinde saat 00:00 başlayan mum
      return (mt.hour == 0 && mt.min == 0);
   }

   //------------------------------------------------------------------
   // YASAKLI ZAMAN 2: Haber saati (MT5 Ekonomik Takvim önbelleği üzerinden)
   // Strategy Tester'da veya takvim verisi yoksa sadece uyarı ver, engelleme.
   //------------------------------------------------------------------
   bool HaberZamaniMi()
   {
      // Takvim verisi hiç dolmadıysa (Tester ortamı veya bağlantı yoksa) geç
      if(m_haberFilt.OnbellekSayisi() < 0)
         return false;   // Uyarı Init'te zaten basıldı, burada engelleme

      return m_haberFilt.HaberZamaniMi(TimeCurrent(), 30);
   }

   //------------------------------------------------------------------
   // YASAKLI ZAMAN 3: Aşırı sert/hacimli mum (spread tehlikesi)
   // Kriter: son mumun aralığı, son 20 barın ortalamasının 3 katından büyük
   //------------------------------------------------------------------
   bool AsiriSertMumMu()
   {
      double aralik1 = iHigh(m_sembol, m_zaman, 1) - iLow(m_sembol, m_zaman, 1);
      double toplamAralik = 0;
      for(int i = 2; i <= 21; i++)
         toplamAralik += iHigh(m_sembol, m_zaman, i) - iLow(m_sembol, m_zaman, i);
      double ortAralik = toplamAralik / 20.0;

      return (aralik1 > ortAralik * 3.0);
   }

   //------------------------------------------------------------------
   // H4 TREND ONAYI: H4 RSI yönü H1 sinyaliyle uyuşuyor mu?
   // "Öneri" seviyesi — false döndürse de işlemi engellemez, sadece loglar.
   // Zorunlu filtre olarak kullanılmaz; çağıran kod uyarı amaçlı okur.
   //------------------------------------------------------------------
   bool H4TrendUyumuMu(bool alisSenaryosu)
   {
      double rsiH4 = IndikatorDeger(m_rsiH4Handle, 0, 1);
      if(rsiH4 == EMPTY_VALUE) return true;

      // Alış için H4 RSI < 65, satış için > 35 (geniş bant)
      return (alisSenaryosu ? rsiH4 < 65.0 : rsiH4 > 35.0);
   }

public:
   //------------------------------------------------------------------
   // Kurucu
   //------------------------------------------------------------------
   CSignal(string sembol, ENUM_TIMEFRAMES zaman)
      : m_sembol(sembol), m_zaman(zaman),
        m_rsiHandle(INVALID_HANDLE),
        m_macdHandle(INVALID_HANDLE),
        m_rsiH4Handle(INVALID_HANDLE),
        m_sonBarZamani(0) {}

   //------------------------------------------------------------------
   // Init: İndikatör handle'larını oluştur, haber filtresini başlat
   //------------------------------------------------------------------
   bool Init()
   {
      // H1 RSI (periyot 14)
      m_rsiHandle = iRSI(m_sembol, PERIOD_H1, 14, PRICE_CLOSE);
      if(m_rsiHandle == INVALID_HANDLE)
      { Print("HATA: H1 RSI handle oluşturulamadı!"); return false; }

      // H1 MACD (12,26,9)
      m_macdHandle = iMACD(m_sembol, PERIOD_H1, 12, 26, 9, PRICE_CLOSE);
      if(m_macdHandle == INVALID_HANDLE)
      { Print("HATA: H1 MACD handle oluşturulamadı!"); return false; }

      // H4 RSI (trend onayı)
      m_rsiH4Handle = iRSI(m_sembol, PERIOD_H4, 14, PRICE_CLOSE);
      if(m_rsiH4Handle == INVALID_HANDLE)
      { Print("HATA: H4 RSI handle oluşturulamadı!"); return false; }

      // MT5 Ekonomik Takvim haber filtresi — sembolden para birimlerini otomatik algılar
      if(!m_haberFilt.Init(m_sembol))
      { Print("UYARI: Haber filtresi başlatılamadı — haber filtresi devre dışı."); }

      Print("CSignal başlatıldı — Sembol: ", m_sembol,
            " | Ana TF: H1 | Trend TF: H4");
      return true;
   }

   //------------------------------------------------------------------
   // Deinit: İndikatör handle'larını serbest bırak
   //------------------------------------------------------------------
   void Deinit()
   {
      if(m_rsiHandle   != INVALID_HANDLE) IndicatorRelease(m_rsiHandle);
      if(m_macdHandle  != INVALID_HANDLE) IndicatorRelease(m_macdHandle);
      if(m_rsiH4Handle != INVALID_HANDLE) IndicatorRelease(m_rsiH4Handle);

      Print("CSignal kapatıldı.");
   }

   //------------------------------------------------------------------
   // SinyalAl: Ana sinyal fonksiyonu
   // PRZ eşiği: 3/5 koşul (gevşetildi — eskiden 5/5 idi)
   // H4 trend: zorunlu değil, "öneri" — engellemiyor, sadece logluyor
   // Döndürür: SIGNAL_AL, SIGNAL_SAT veya SIGNAL_YOK
   //------------------------------------------------------------------
   ENUM_SIGNAL SinyalAl()
   {
      // === YENİ BAR KORUMASI ===
      // Tüm hesaplar ve loglar sadece yeni H1 bar açılışında çalışır.
      // Aynı bar içindeki sonraki tickler sessizce SIGNAL_YOK döner.
      datetime barZamani = iTime(m_sembol, m_zaman, 1);
      if(barZamani == m_sonBarZamani)
         return SIGNAL_YOK;
      m_sonBarZamani = barZamani;

      // === YASAKLI ZAMAN KONTROLÜ ===
      if(GeceyarisiBariMi())
         return SIGNAL_YOK;

      if(HaberZamaniMi())
      {
         Print("PRZ: Haber saati — islem engellendi. (",
               TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES), ")");
         return SIGNAL_YOK;
      }
      if(AsiriSertMumMu())
      {
         Print("PRZ: Asiri sert mum — engellendi.");
         return SIGNAL_YOK;
      }

      double fiyat = iClose(m_sembol, m_zaman, 1);

      // === ALIŞI SENARYOSU ===
      int alisPuan = PRZPuanHesapla(fiyat, true);
      bool alisH4  = H4TrendUyumuMu(true);

      if(alisPuan >= 3)   // Eşik: 5 → 3
      {
         ENUM_TETIKLEYICI tetik = TetikleyiciMumKontrol(true);

         // Detaylı log: neden geçti veya neden reddedildi
         Print("PRZ ALIS degerlendirme | Fiyat: ", DoubleToString(fiyat, _Digits),
               " | Puan: ", alisPuan, "/5",
               " | H4Trend: ", (alisH4 ? "OK" : "ZAYIF"),
               " | Tetik: ", EnumToString(tetik));

         if(tetik != TETIK_YOK)
         {
            if(!alisH4)
               Print("PRZ ALIS: H4 trend zayif ama devam ediliyor (oneri seviyesi).");
            Print(">>> PRZ AL Sinyali | Puan: ", alisPuan,
                  " | Tetikleyici: ", EnumToString(tetik));
            return SIGNAL_AL;
         }
         else
            Print("PRZ ALIS RED: Tetikleyici mum yok (puan=", alisPuan, ").");
      }
      else if(alisPuan > 0)
      {
         Print("PRZ ALIS yetersiz puan: ", alisPuan, "/5 (min 3 gerekli)",
               " | Fiyat: ", DoubleToString(fiyat, _Digits));
      }

      // === SATIŞ SENARYOSU ===
      int satisPuan = PRZPuanHesapla(fiyat, false);
      bool satisH4  = H4TrendUyumuMu(false);

      if(satisPuan >= 3)   // Eşik: 5 → 3
      {
         ENUM_TETIKLEYICI tetik = TetikleyiciMumKontrol(false);

         Print("PRZ SATIS degerlendirme | Fiyat: ", DoubleToString(fiyat, _Digits),
               " | Puan: ", satisPuan, "/5",
               " | H4Trend: ", (satisH4 ? "OK" : "ZAYIF"),
               " | Tetik: ", EnumToString(tetik));

         if(tetik != TETIK_YOK)
         {
            if(!satisH4)
               Print("PRZ SATIS: H4 trend zayif ama devam ediliyor (oneri seviyesi).");
            Print(">>> PRZ SAT Sinyali | Puan: ", satisPuan,
                  " | Tetikleyici: ", EnumToString(tetik));
            return SIGNAL_SAT;
         }
         else
            Print("PRZ SATIS RED: Tetikleyici mum yok (puan=", satisPuan, ").");
      }
      else if(satisPuan > 0)
      {
         Print("PRZ SATIS yetersiz puan: ", satisPuan, "/5 (min 3 gerekli)",
               " | Fiyat: ", DoubleToString(fiyat, _Digits));
      }

      return SIGNAL_YOK;
   }

   //------------------------------------------------------------------
   // Erişiciler
   //------------------------------------------------------------------
   string          Sembol() const { return m_sembol; }
   ENUM_TIMEFRAMES Zaman()  const { return m_zaman;  }
};
#endif // CSIGNAL_MQH
