//+------------------------------------------------------------------+
//|  CSignal.mqh — Sinyal Üretim Modülü                             |
//|  Strateji: PRZ (S/R Flip + Fibo) + RSI + MACD Div + Tetik Mum  |
//+------------------------------------------------------------------+
#ifndef CSIGNAL_MQH
#define CSIGNAL_MQH

//--- Sinyal değerleri
enum ENUM_SIGNAL
{
   SIGNAL_YOK  =  0,   // Bekle, işlem yapma
   SIGNAL_AL   =  1,   // Alış sinyali
   SIGNAL_SAT  = -1    // Satış sinyali
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
//====================================================================
class CNewsFilter
{
private:
   datetime m_onbellekHaberler[];
   int      m_onbellekSayisi;
   datetime m_onbellekGunu;
   string   m_paraBirimleri[];
   int      m_paraBirimiSayisi;

   datetime BugunBaslangici()
   {
      MqlDateTime md;
      TimeToStruct(TimeCurrent(), md);
      md.hour = 0; md.min = 0; md.sec = 0;
      return StructToTime(md);
   }

   datetime YarinBaslangici() { return BugunBaslangici() + 86400; }

   void SemboldenParaBirimleriCikar(string sembol)
   {
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
         ArrayResize(m_paraBirimleri, 2);
         m_paraBirimleri[0] = StringSubstr(temiz, 0, 3);
         m_paraBirimleri[1] = StringSubstr(temiz, 3, 3);
         m_paraBirimiSayisi = 2;
      }
      else if(uzunluk > 0)
      {
         ArrayResize(m_paraBirimleri, 1);
         m_paraBirimleri[0] = temiz;
         m_paraBirimiSayisi = 1;
      }
   }

   bool HaberParaBirimiEslesiyor(string pb)
   {
      if(m_paraBirimiSayisi == 0) return true;
      for(int i = 0; i < m_paraBirimiSayisi; i++)
         if(m_paraBirimleri[i] == pb) return true;
      return false;
   }

   void OnbellekGuncelle()
   {
      datetime bugun = BugunBaslangici();
      if(m_onbellekGunu == bugun && m_onbellekSayisi >= 0) return;

      m_onbellekGunu   = bugun;
      m_onbellekSayisi = 0;
      ArrayResize(m_onbellekHaberler, 0);

      MqlCalendarValue haberDizisi[];
      int adet = CalendarValueHistory(haberDizisi, bugun, YarinBaslangici());
      if(adet <= 0) { Print("CNewsFilter: Takvim verisi alinamadi."); return; }

      for(int i = 0; i < adet; i++)
      {
         MqlCalendarEvent olay;
         if(!CalendarEventById(haberDizisi[i].event_id, olay)) continue;
         if(olay.importance != CALENDAR_IMPORTANCE_HIGH) continue;
         MqlCalendarCountry ulke;
         if(CalendarCountryById(olay.country_id, ulke))
            if(!HaberParaBirimiEslesiyor(ulke.currency)) continue;
         ArrayResize(m_onbellekHaberler, m_onbellekSayisi + 1);
         m_onbellekHaberler[m_onbellekSayisi++] = haberDizisi[i].time;
      }
      Print("CNewsFilter: ", m_onbellekSayisi, " yuksek onemli haber onbelleklendi.");
   }

public:
   CNewsFilter() : m_onbellekSayisi(-1), m_onbellekGunu(0), m_paraBirimiSayisi(0) {}

   bool Init(string sembol)
   {
      SemboldenParaBirimleriCikar(sembol);
      OnbellekGuncelle();
      Print("CNewsFilter basladi — ", sembol);
      return true;
   }

   bool HaberZamaniMi(datetime zaman, int pencereDakika = 30)
   {
      if(m_onbellekGunu != BugunBaslangici()) OnbellekGuncelle();
      int sn = pencereDakika * 60;
      for(int i = 0; i < m_onbellekSayisi; i++)
         if(MathAbs((long)(zaman - m_onbellekHaberler[i])) <= sn) return true;
      return false;
   }

   int OnbellekSayisi()   const { return m_onbellekSayisi;   }
   int ParaBirimiSayisi() const { return m_paraBirimiSayisi; }
};

//====================================================================
//  CSignal — Ana Sinyal Sinifi
//  Algoritma: PRZ onay + MACD uyumsuzluk + Tetikleyici mum
//====================================================================
class CSignal
{
private:
   //--- Indiktor handle'lari
   int   m_rsiHandle;      // H1 RSI(14)
   int   m_macdHandle;     // H1 MACD(12,26,9) — histogram tampon 2
   int   m_fractalsHandle; // H1 iFractals — yukaridaki(0) ve asagidaki(1) tamponlar
   int   m_rsiH4Handle;    // H4 RSI(14) — trend onerisi

   string          m_sembol;
   ENUM_TIMEFRAMES m_zaman;
   CNewsFilter     m_haberFilt;
   datetime        m_sonBarZamani;

   //------------------------------------------------------------------
   // YARDIMCI: Tek tampon degeri oku (as-series)
   //------------------------------------------------------------------
   double IndikatorDeger(int handle, int tampon, int bar)
   {
      double arr[];
      ArraySetAsSeries(arr, true);
      if(CopyBuffer(handle, tampon, bar, 1, arr) <= 0) return EMPTY_VALUE;
      return arr[0];
   }

   //------------------------------------------------------------------
   // YARDIMCI: Fraktal dizisini oku — bos (EMPTY_VALUE) degerleri atlayarak
   // en yakin N adet gecerli fraktal tepe/dibini dondurur.
   // tampon=0 → Fractal High (tepeler), tampon=1 → Fractal Low (dipler)
   // Dondurulen dizi: [0]=en yakin, [1]=ikinci yakin, ...
   // Dondurulen deger: bar indeksi (fiyat icin iHigh/iLow(bar) kullanilir)
   //------------------------------------------------------------------
   int FraktalBarlariAl(int tampon, int aramaDerinligi, int &barlar[], int istenen)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      // iFractals en az 5 bar gerektirir; shift 2'den itibaren gecerli
      if(CopyBuffer(m_fractalsHandle, tampon, 2, aramaDerinligi, buf) <= 0) return 0;

      int bulunan = 0;
      ArrayResize(barlar, istenen);

      for(int i = 0; i < aramaDerinligi && bulunan < istenen; i++)
      {
         if(buf[i] != EMPTY_VALUE && buf[i] > 0)
         {
            barlar[bulunan] = i + 2;   // gercek bar indeksi (shift 2 offset)
            bulunan++;
         }
      }
      return bulunan;
   }

   //------------------------------------------------------------------
   // YASAKLI ZAMAN: Gece 00:00 mumu
   //------------------------------------------------------------------
   bool GeceyarisiBariMi()
   {
      MqlDateTime mt;
      TimeToStruct(iTime(m_sembol, m_zaman, 1), mt);
      return (mt.hour == 0 && mt.min == 0);
   }

   //------------------------------------------------------------------
   // YASAKLI ZAMAN: Haber penceresi (takvim verisi yoksa gecir)
   //------------------------------------------------------------------
   bool HaberZamaniMi()
   {
      if(m_haberFilt.OnbellekSayisi() < 0) return false;
      return m_haberFilt.HaberZamaniMi(TimeCurrent(), 30);
   }

   //------------------------------------------------------------------
   // YASAKLI ZAMAN: Asiri sert mum (ATR x3)
   //------------------------------------------------------------------
   bool AsiriSertMumMu()
   {
      double aralik1 = iHigh(m_sembol, m_zaman, 1) - iLow(m_sembol, m_zaman, 1);
      double toplam  = 0;
      for(int i = 2; i <= 21; i++)
         toplam += iHigh(m_sembol, m_zaman, i) - iLow(m_sembol, m_zaman, i);
      return (aralik1 > (toplam / 20.0) * 3.0);
   }

   //------------------------------------------------------------------
   // SART 1A — S/R Flip:
   // Fraktal High kirilmis → fiyat o seviyeye destek olarak geri dondu  (alis)
   // Fraktal Low  kirilmis → fiyat o seviyeye direnc olarak geri dondu  (satis)
   // Kontrol: kapanis barin fraktal seviyesine tolerans mesafesinde mi?
   //------------------------------------------------------------------
   bool SRFlipMi(double kapanis, bool alis)
   {
      double tolerans = 15 * _Point;
      int barlar[];
      // Alis: kirilmis eski direnc (fraktal tepe) simdi destek oldu mu?
      // Satis: kirilmis eski destek (fraktal dip) simdi direnc oldu mu?
      int tampon = alis ? 0 : 1;   // 0=High fractals, 1=Low fractals
      int adet   = FraktalBarlariAl(tampon, 200, barlar, 10);

      for(int i = 0; i < adet; i++)
      {
         int    b        = barlar[i];
         double seviye   = alis ? iHigh(m_sembol, m_zaman, b)
                                : iLow (m_sembol, m_zaman, b);

         // Fraktalin kirilip kirilmadigini kontrol et:
         // Alis  → fraktal tepe kapanis ile asilmis olmali (fiyat once yukari kirdi)
         //         ve simdi o seviyeye destek olarak geri donmeli
         // Satis → fraktal dip kapanis ile asilmis olmali
         //         ve simdi o seviyeye direnc olarak geri donmeli
         bool kirilmis;
         if(alis)
            kirilmis = (iClose(m_sembol, m_zaman, b - 1) > seviye);  // kirildiktan sonraki bar
         else
            kirilmis = (iClose(m_sembol, m_zaman, b - 1) < seviye);

         if(!kirilmis) continue;

         // Simdi fiyat o seviyeye geri donmus mu?
         if(MathAbs(kapanis - seviye) <= tolerans)
            return true;
      }
      return false;
   }

   //------------------------------------------------------------------
   // SART 1B — Fibonacci %61.8 - %78.6 Bolgesi:
   // Son 2 gecerli fraktal tepe/dip arasindaki dalganin fibo bolgesi
   //------------------------------------------------------------------
   bool FiboBolgesindeMi(double kapanis, bool alis)
   {
      int yuksekBarlar[], dusukBarlar[];
      int ny = FraktalBarlariAl(0, 150, yuksekBarlar, 2);
      int nd = FraktalBarlariAl(1, 150, dusukBarlar,  2);
      if(ny < 2 || nd < 2) return false;

      // Son swing: en yakin fraktal tepe ve dip
      double swingYuksek = iHigh(m_sembol, m_zaman, yuksekBarlar[0]);
      double swingDusuk  = iLow (m_sembol, m_zaman, dusukBarlar [0]);
      double aralik      = swingYuksek - swingDusuk;
      if(aralik < _Point * 10) return false;

      double tolerans = aralik * 0.01;   // %1 bant genisligi

      if(alis)
      {
         // Alis: swingDusuk'tan yukari olcumlenen %61.8 - %78.6
         double f618 = swingDusuk + aralik * 0.618;
         double f786 = swingDusuk + aralik * 0.786;  // not: asagi retracement, dusukten yukari
         // Aslinda alis retracementi: fiyat asagidan %61.8-%78.6'ya geldi
         // Yani swingYuksek - aralik*0.786 ile swingYuksek - aralik*0.618 arasi
         double alt = swingYuksek - aralik * 0.786;
         double ust = swingYuksek - aralik * 0.618;
         return (kapanis >= alt - tolerans && kapanis <= ust + tolerans);
      }
      else
      {
         // Satis: swingYuksek'ten asagi olcumlenen %61.8 - %78.6 retracement
         double alt = swingDusuk  + aralik * 0.618;
         double ust = swingDusuk  + aralik * 0.786;
         return (kapanis >= alt - tolerans && kapanis <= ust + tolerans);
      }
   }

   //------------------------------------------------------------------
   // SART 1C — RSI Asiri Alim/Satim:
   // Alis icin RSI(14) <= 30, Satis icin >= 70
   //------------------------------------------------------------------
   bool RSIAsiriMi(bool alis)
   {
      double rsi = IndikatorDeger(m_rsiHandle, 0, 1);
      if(rsi == EMPTY_VALUE) return false;
      return alis ? (rsi <= 30.0) : (rsi >= 70.0);
   }

   //------------------------------------------------------------------
   // H4 TREND ONERISI (zorunlu degil — log icin)
   //------------------------------------------------------------------
   bool H4TrendUyumuMu(bool alis)
   {
      double rsi = IndikatorDeger(m_rsiH4Handle, 0, 1);
      if(rsi == EMPTY_VALUE) return true;
      return alis ? (rsi < 65.0) : (rsi > 35.0);
   }

public:
   //------------------------------------------------------------------
   // Kurucu
   //------------------------------------------------------------------
   CSignal(string sembol, ENUM_TIMEFRAMES zaman)
      : m_sembol(sembol), m_zaman(zaman),
        m_rsiHandle(INVALID_HANDLE),
        m_macdHandle(INVALID_HANDLE),
        m_fractalsHandle(INVALID_HANDLE),
        m_rsiH4Handle(INVALID_HANDLE),
        m_sonBarZamani(0) {}

   //------------------------------------------------------------------
   // Init
   //------------------------------------------------------------------
   bool Init()
   {
      m_rsiHandle = iRSI(m_sembol, m_zaman, 14, PRICE_CLOSE);
      if(m_rsiHandle == INVALID_HANDLE)
      { Print("HATA: RSI handle olusturulamadi!"); return false; }

      m_macdHandle = iMACD(m_sembol, m_zaman, 12, 26, 9, PRICE_CLOSE);
      if(m_macdHandle == INVALID_HANDLE)
      { Print("HATA: MACD handle olusturulamadi!"); return false; }

      // iFractals: tampon 0 = High fractals, tampon 1 = Low fractals
      m_fractalsHandle = iFractals(m_sembol, m_zaman);
      if(m_fractalsHandle == INVALID_HANDLE)
      { Print("HATA: Fractals handle olusturulamadi!"); return false; }

      m_rsiH4Handle = iRSI(m_sembol, PERIOD_H4, 14, PRICE_CLOSE);
      if(m_rsiH4Handle == INVALID_HANDLE)
      { Print("HATA: H4 RSI handle olusturulamadi!"); return false; }

      if(!m_haberFilt.Init(m_sembol))
         Print("UYARI: Haber filtresi baslatılamadı.");

      Print("CSignal basladi | Sembol: ", m_sembol, " | TF: ", EnumToString(m_zaman));
      return true;
   }

   //------------------------------------------------------------------
   // Deinit
   //------------------------------------------------------------------
   void Deinit()
   {
      if(m_rsiHandle      != INVALID_HANDLE) IndicatorRelease(m_rsiHandle);
      if(m_macdHandle     != INVALID_HANDLE) IndicatorRelease(m_macdHandle);
      if(m_fractalsHandle != INVALID_HANDLE) IndicatorRelease(m_fractalsHandle);
      if(m_rsiH4Handle    != INVALID_HANDLE) IndicatorRelease(m_rsiH4Handle);
      Print("CSignal kapatildi.");
   }

   //------------------------------------------------------------------
   // SART 1 — FiyatPRZBolgesindeMi:
   // (S/R Flip VEYA Fibo %61.8-%78.6) VE RSI asiri alim/satim
   //------------------------------------------------------------------
   bool FiyatPRZBolgesindeMi(bool alis)
   {
      double kapanis = iClose(m_sembol, m_zaman, 1);

      bool srFlip = SRFlipMi    (kapanis, alis);
      bool fibo   = FiboBolgesindeMi(kapanis, alis);
      bool rsi    = RSIAsiriMi  (alis);

      Print("PRZ kontrol | Yon=", (alis ? "AL" : "SAT"),
            " | SRFlip=", srFlip,
            " | Fibo=",   fibo,
            " | RSI=",    rsi,
            " | Fiyat=",  DoubleToString(kapanis, _Digits));

      return ((srFlip || fibo) && rsi);
   }

   //------------------------------------------------------------------
   // SART 2 — UyumsuzlukVarMi:
   // En son 2 fraktal tepe/dip ile o barlardaki MACD histogram degerlerini
   // karsilastir.
   //   AL (Bullish div) : Fiyat LL yaparken MACD HL — dondurur  1
   //   SAT (Bearish div): Fiyat HH yaparken MACD LH — dondurur -1
   //   Yok               :                           — dondurur  0
   //------------------------------------------------------------------
   int UyumsuzlukVarMi()
   {
      // --- BULLIS DIV: son 2 fraktal dip ---
      int dipBarlar[];
      if(FraktalBarlariAl(1, 150, dipBarlar, 2) == 2)
      {
         int   b1 = dipBarlar[0];   // daha yakin dip
         int   b2 = dipBarlar[1];   // daha eski dip

         double fiyat1 = iLow(m_sembol, m_zaman, b1);
         double fiyat2 = iLow(m_sembol, m_zaman, b2);

         // MACD histogram: tampon indeksi 2
         double macd1  = IndikatorDeger(m_macdHandle, 2, b1);
         double macd2  = IndikatorDeger(m_macdHandle, 2, b2);

         if(macd1 != EMPTY_VALUE && macd2 != EMPTY_VALUE)
         {
            bool fiyatLL = (fiyat1 < fiyat2);   // Lower Low
            bool macdHL  = (macd1  > macd2);    // Higher Low (histogram daha az negatif)

            Print("Div AL kontrol | Fiyat1=", DoubleToString(fiyat1, _Digits),
                  " Fiyat2=", DoubleToString(fiyat2, _Digits),
                  " | MACD1=", DoubleToString(macd1, 8),
                  " MACD2=",   DoubleToString(macd2, 8),
                  " | LL=", fiyatLL, " HL=", macdHL);

            if(fiyatLL && macdHL) return 1;
         }
      }

      // --- BEARISH DIV: son 2 fraktal tepe ---
      int tepeBarlar[];
      if(FraktalBarlariAl(0, 150, tepeBarlar, 2) == 2)
      {
         int   b1 = tepeBarlar[0];
         int   b2 = tepeBarlar[1];

         double fiyat1 = iHigh(m_sembol, m_zaman, b1);
         double fiyat2 = iHigh(m_sembol, m_zaman, b2);

         double macd1  = IndikatorDeger(m_macdHandle, 2, b1);
         double macd2  = IndikatorDeger(m_macdHandle, 2, b2);

         if(macd1 != EMPTY_VALUE && macd2 != EMPTY_VALUE)
         {
            bool fiyatHH = (fiyat1 > fiyat2);   // Higher High
            bool macdLH  = (macd1  < macd2);    // Lower High  (histogram daha az pozitif)

            Print("Div SAT kontrol | Fiyat1=", DoubleToString(fiyat1, _Digits),
                  " Fiyat2=", DoubleToString(fiyat2, _Digits),
                  " | MACD1=", DoubleToString(macd1, 8),
                  " MACD2=",   DoubleToString(macd2, 8),
                  " | HH=", fiyatHH, " LH=", macdLH);

            if(fiyatHH && macdLH) return -1;
         }
      }

      return 0;
   }

   //------------------------------------------------------------------
   // SART 3 — TetikleyiciMumGeldMii:
   // Shift 1 (kapanmis mum) uzerinde 3 formasyon arar.
   // Pinbar kurali: mumu 4 esit dilime bol (%25'lik).
   //   AL pinbar : Close en ust %25'te && alt fitil uzun
   //   SAT pinbar: Close en alt %25'te && ust fitil uzun
   // Engulfing (fitil dahil yutma):
   //   AL: High[1]>High[2] && Low[1]<Low[2] && Close[1]>Open[1]
   //   SAT: tam tersi
   // HHHC / LLLC:
   //   AL (HHHC): Low[1]>Low[2] && High[1]>High[2] && Close[1]>Close[2]
   //   SAT(LLLC): Low[1]<Low[2] && High[1]<High[2] && Close[1]<Close[2]
   // Dondurur: TETIK_PINBAR | TETIK_ENGULFING | TETIK_HHHC_LLLC | TETIK_YOK
   //------------------------------------------------------------------
   ENUM_TETIKLEYICI TetikleyiciMumGeldMii(bool alis)
   {
      double o1 = iOpen (m_sembol, m_zaman, 1);
      double c1 = iClose(m_sembol, m_zaman, 1);
      double h1 = iHigh (m_sembol, m_zaman, 1);
      double l1 = iLow  (m_sembol, m_zaman, 1);

      double o2 = iOpen (m_sembol, m_zaman, 2);
      double c2 = iClose(m_sembol, m_zaman, 2);
      double h2 = iHigh (m_sembol, m_zaman, 2);
      double l2 = iLow  (m_sembol, m_zaman, 2);

      double aralik = h1 - l1;
      if(aralik < _Point * 5) return TETIK_YOK;   // Anlamsiz kucuk mum

      double dilim = aralik / 4.0;   // %25'lik dilim

      // --- PINBAR ---
      if(alis)
      {
         // Kapanis en ust %25 diliminde olmali: c1 >= l1 + 3*dilim
         bool kapanisUstte = (c1 >= l1 + 3.0 * dilim);
         // Alt fitil uzun: gövde altindan dip'e mesafe > aralik*%50
         double altFitil = MathMin(o1, c1) - l1;
         bool altFitilUzun = (altFitil >= aralik * 0.5);
         if(kapanisUstte && altFitilUzun) return TETIK_PINBAR;
      }
      else
      {
         // Kapanis en alt %25 diliminde olmali: c1 <= l1 + dilim
         bool kapanisAltta = (c1 <= l1 + dilim);
         // Ust fitil uzun
         double ustFitil = h1 - MathMax(o1, c1);
         bool ustFitilUzun = (ustFitil >= aralik * 0.5);
         if(kapanisAltta && ustFitilUzun) return TETIK_PINBAR;
      }

      // --- ENGULFING (fitil dahil) ---
      if(alis)
      {
         // Onceki mum bearish, simdi bullish, fitil dahil yutuyor
         bool oncekiBearish  = (c2 < o2);
         bool simdikiBullish = (c1 > o1);
         bool yutuyor        = (h1 > h2 && l1 < l2);
         if(oncekiBearish && simdikiBullish && yutuyor) return TETIK_ENGULFING;
      }
      else
      {
         bool oncekiBullish  = (c2 > o2);
         bool simdikiBearish = (c1 < o1);
         bool yutuyor        = (h1 > h2 && l1 < l2);
         if(oncekiBullish && simdikiBearish && yutuyor) return TETIK_ENGULFING;
      }

      // --- HHHC / LLLC ---
      if(alis)
      {
         // Higher Low, Higher High, Higher Close (HHHC)
         if(l1 > l2 && h1 > h2 && c1 > c2) return TETIK_HHHC_LLLC;
      }
      else
      {
         // Lower Low, Lower High, Lower Close (LLLC)
         if(l1 < l2 && h1 < h2 && c1 < c2) return TETIK_HHHC_LLLC;
      }

      return TETIK_YOK;
   }

   //------------------------------------------------------------------
   // SinyalAl: Nihai karar
   // Kosul: PRZ onay VE MACD uyumsuzlugu VE tetikleyici mum
   // Dondurur: SIGNAL_AL | SIGNAL_SAT | SIGNAL_YOK
   //------------------------------------------------------------------
   ENUM_SIGNAL SinyalAl()
   {
      // === YENİ BAR KORUMASI ===
      datetime barZamani = iTime(m_sembol, m_zaman, 1);
      if(barZamani == m_sonBarZamani) return SIGNAL_YOK;
      m_sonBarZamani = barZamani;

      // === YASAKLI ZAMANLAR ===
      if(GeceyarisiBariMi()) return SIGNAL_YOK;

      if(HaberZamaniMi())
      {
         Print("SINYAL: Haber saati — engellendi (",
               TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES), ")");
         return SIGNAL_YOK;
      }
      if(AsiriSertMumMu())
      {
         Print("SINYAL: Asiri sert mum — engellendi.");
         return SIGNAL_YOK;
      }

      // === MACD UYUMSUZLUGU (yön belirleyici) ===
      int divYon = UyumsuzlukVarMi();   // 1=bullish, -1=bearish, 0=yok

      if(divYon == 0)
      {
         Print("SINYAL: MACD uyumsuzlugu yok — gecildi.");
         return SIGNAL_YOK;
      }

      bool alis = (divYon == 1);

      // === SART 1: PRZ ===
      bool przOnay = FiyatPRZBolgesindeMi(alis);
      if(!przOnay)
      {
         Print("SINYAL: PRZ bolgesi onaylı degil — RED | Yon=", (alis ? "AL" : "SAT"));
         return SIGNAL_YOK;
      }

      // === SART 3: TETIKLEYICI MUM ===
      ENUM_TETIKLEYICI tetik = TetikleyiciMumGeldMii(alis);
      if(tetik == TETIK_YOK)
      {
         Print("SINYAL: PRZ+Div onaylı ama tetikleyici mum yok | Yon=", (alis ? "AL" : "SAT"));
         return SIGNAL_YOK;
      }

      // === H4 TREND ONERISI (engellemiyor) ===
      bool h4uyum = H4TrendUyumuMu(alis);
      if(!h4uyum)
         Print("SINYAL: H4 trend zayif ama devam ediliyor (oneri).");

      Print(">>> SINYAL ", (alis ? "AL" : "SAT"),
            " | Tetik=", EnumToString(tetik),
            " | Div=",   (divYon == 1 ? "Bullish" : "Bearish"),
            " | H4=",    (h4uyum ? "OK" : "ZAYIF"),
            " | Bar=",   TimeToString(barZamani, TIME_DATE|TIME_MINUTES));

      return alis ? SIGNAL_AL : SIGNAL_SAT;
   }

   //------------------------------------------------------------------
   // Erisiciler
   //------------------------------------------------------------------
   string          Sembol() const { return m_sembol; }
   ENUM_TIMEFRAMES Zaman()  const { return m_zaman;  }
};
#endif // CSIGNAL_MQH
