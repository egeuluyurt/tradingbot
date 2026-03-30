//+------------------------------------------------------------------+
//|  CWizard.mqh — İlk Çalıştırma Sihirbazı                         |
//|  4 adımda bağlantı, hesap, ayar kontrolü ve hazır bildirimi     |
//|  GlobalVariables ile "kurulum tamamlandı" bilgisini saklar       |
//+------------------------------------------------------------------+
#pragma once

//====================================================================
//  SABİTLER
//====================================================================
#define WIZ_ONEK            "WIZ_"
#define WIZ_GV_TAMAMLANDI   "TradingBot_KurulumTamamlandi"  // GlobalVariable adı
#define WIZ_GV_ADIM         "TradingBot_SonAdim"
#define WIZ_GRAFIK          0             // Hangi grafik üzerinde çalışır
#define WIZ_GENISLIK        500           // Sihirbaz pencere genişliği
#define WIZ_YUKSEKLIK       380           // Sihirbaz pencere yüksekliği
#define WIZ_ADIM_BEKLEME    2000          // Adımlar arası bekleme (ms)

//--- Koyu tema
#define WIZ_BG              C'25,25,40'
#define WIZ_BG_BASLIK       C'40,40,70'
#define WIZ_BG_ICERIK       C'30,30,50'
#define WIZ_BG_DUGME_TAMAM  C'40,160,80'
#define WIZ_BG_DUGME_ATLA   C'70,70,100'
#define WIZ_KENAR           C'80,80,130'
#define WIZ_METIN           C'220,220,240'
#define WIZ_DIM             C'140,140,170'
#define WIZ_YESIL           C'80,220,120'
#define WIZ_KIRMIZI         C'230,80,80'
#define WIZ_TURUNCU         C'230,150,50'
#define WIZ_SARI            C'240,210,60'
#define WIZ_MAVI            C'100,160,255'

//====================================================================
//  CWizard
//====================================================================
class CWizard
{
private:
   long     m_grafik;
   int      m_mevcutAdim;        // 0 = henüz başlamadı, 1-4 = adımlar, 5 = tamamlandı
   bool     m_tekrarGosterme;    // Kullanıcı "bir daha gösterme" seçtiyse true
   bool     m_tamamlandi;        // Sihirbaz başarıyla bitti mi?

   // Ekranın ortasına konumlandırmak için başlangıç koordinatları
   int      m_startX;
   int      m_startY;

   //------------------------------------------------------------------
   // YARDIMCI — Nesne adı
   //------------------------------------------------------------------
   string N(string tag) { return WIZ_ONEK + tag; }

   //------------------------------------------------------------------
   // YARDIMCI — Dikdörtgen kutu
   //------------------------------------------------------------------
   void Kutu(string tag, int x, int y, int w, int h,
             color bg, color kenarlık = WIZ_KENAR)
   {
      string ad = N(tag);
      if(ObjectFind(m_grafik, ad) < 0)
         ObjectCreate(m_grafik, ad, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(m_grafik, ad, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
      ObjectSetInteger(m_grafik, ad, OBJPROP_XDISTANCE,   x);
      ObjectSetInteger(m_grafik, ad, OBJPROP_YDISTANCE,   y);
      ObjectSetInteger(m_grafik, ad, OBJPROP_XSIZE,       w);
      ObjectSetInteger(m_grafik, ad, OBJPROP_YSIZE,       h);
      ObjectSetInteger(m_grafik, ad, OBJPROP_BGCOLOR,     bg);
      ObjectSetInteger(m_grafik, ad, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(m_grafik, ad, OBJPROP_COLOR,       kenarlık);
      ObjectSetInteger(m_grafik, ad, OBJPROP_SELECTABLE,  false);
      ObjectSetInteger(m_grafik, ad, OBJPROP_HIDDEN,      true);
      ObjectSetInteger(m_grafik, ad, OBJPROP_ZORDER,      10);
   }

   //------------------------------------------------------------------
   // YARDIMCI — Etiket (metin)
   //------------------------------------------------------------------
   void Metin(string tag, int x, int y, string txt, color renk,
              int boyut = 9, string font = "Segoe UI")
   {
      string ad = N(tag);
      if(ObjectFind(m_grafik, ad) < 0)
      {
         ObjectCreate(m_grafik, ad, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(m_grafik, ad, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(m_grafik, ad, OBJPROP_HIDDEN,     true);
         ObjectSetInteger(m_grafik, ad, OBJPROP_ZORDER,     11);
      }
      ObjectSetInteger(m_grafik, ad, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
      ObjectSetInteger(m_grafik, ad, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_grafik, ad, OBJPROP_YDISTANCE, y);
      ObjectSetString (m_grafik, ad, OBJPROP_TEXT,      txt);
      ObjectSetInteger(m_grafik, ad, OBJPROP_COLOR,     renk);
      ObjectSetInteger(m_grafik, ad, OBJPROP_FONTSIZE,  boyut);
      ObjectSetString (m_grafik, ad, OBJPROP_FONT,      font);
   }

   //------------------------------------------------------------------
   // YARDIMCI — Düğme
   //------------------------------------------------------------------
   void Dugme(string tag, int x, int y, int w, int h,
              string txt, color bg, color txtRenk = WIZ_METIN)
   {
      string ad = N(tag);
      if(ObjectFind(m_grafik, ad) < 0)
         ObjectCreate(m_grafik, ad, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(m_grafik, ad, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
      ObjectSetInteger(m_grafik, ad, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_grafik, ad, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_grafik, ad, OBJPROP_XSIZE,     w);
      ObjectSetInteger(m_grafik, ad, OBJPROP_YSIZE,     h);
      ObjectSetString (m_grafik, ad, OBJPROP_TEXT,      txt);
      ObjectSetInteger(m_grafik, ad, OBJPROP_BGCOLOR,   bg);
      ObjectSetInteger(m_grafik, ad, OBJPROP_COLOR,     txtRenk);
      ObjectSetInteger(m_grafik, ad, OBJPROP_FONTSIZE,  10);
      ObjectSetString (m_grafik, ad, OBJPROP_FONT,      "Segoe UI Bold");
      ObjectSetInteger(m_grafik, ad, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(m_grafik, ad, OBJPROP_ZORDER,    12);
   }

   //------------------------------------------------------------------
   // YARDIMCI — İlerleme çubuğu (adım göstergesi)
   //------------------------------------------------------------------
   void IlerlemeGoster(int adim)
   {
      int y    = m_startY + 50;
      int genH = WIZ_GENISLIK - 40;
      int adimW = genH / 4;

      // Dört bölümlü progress bar
      for(int i = 1; i <= 4; i++)
      {
         int bx = m_startX + 20 + (i - 1) * adimW;
         color bg = (i <= adim) ? WIZ_YESIL : C'60,60,90';
         Kutu("prog_" + IntegerToString(i), bx + 2, y, adimW - 4, 6, bg, bg);
      }

      // Adım etiketi
      Metin("prog_txt",
            m_startX + WIZ_GENISLIK / 2 - 40, y + 10,
            "Adım " + IntegerToString(adim) + " / 4",
            WIZ_DIM, 8, "Segoe UI");
   }

   //------------------------------------------------------------------
   // YARDIMCI — Tüm içerik nesnelerini sil (çerçeveyi koru)
   //------------------------------------------------------------------
   void IcerikTemizle()
   {
      // İçerik nesneleri "WIZ_ic_" ile başlar
      for(int i = ObjectsTotal(m_grafik, 0, -1) - 1; i >= 0; i--)
      {
         string ad = ObjectName(m_grafik, i, 0, -1);
         if(StringFind(ad, WIZ_ONEK + "ic_") == 0)
            ObjectDelete(m_grafik, ad);
      }
   }

   //------------------------------------------------------------------
   // İçerik etiketi (temizlenebilir — "ic_" önekli)
   //------------------------------------------------------------------
   void IcMetin(string tag, int x, int y, string txt, color renk,
                int boyut = 9, string font = "Segoe UI")
   {
      Metin("ic_" + tag, x, y, txt, renk, boyut, font);
   }

   //------------------------------------------------------------------
   // Sabit çerçeve — yalnızca bir kez çizilir
   //------------------------------------------------------------------
   void CerceveCiz()
   {
      // Ana arka plan
      Kutu("bg",       m_startX,     m_startY,     WIZ_GENISLIK, WIZ_YUKSEKLIK, WIZ_BG);
      // Başlık şeridi
      Kutu("bg_baslik",m_startX,     m_startY,     WIZ_GENISLIK, 42,            WIZ_BG_BASLIK);
      // İçerik alanı
      Kutu("bg_icerik",m_startX + 10,m_startY + 68,WIZ_GENISLIK - 20, WIZ_YUKSEKLIK - 120, WIZ_BG_ICERIK);

      // Başlık metni
      Metin("baslik",
            m_startX + 15, m_startY + 12,
            "TradingBot v1.0 — Kurulum Sihirbazı",
            WIZ_METIN, 12, "Segoe UI Bold");
   }

   //------------------------------------------------------------------
   // Düğmeleri çiz
   //------------------------------------------------------------------
   void DugmeleriCiz(bool tamamAktif, bool atlaGoster)
   {
      int dugY  = m_startY + WIZ_YUKSEKLIK - 50;
      int dugW  = 160;

      if(tamamAktif)
         Dugme("btn_tamam",
               m_startX + WIZ_GENISLIK / 2 - dugW / 2,
               dugY, dugW, 32,
               "Tamam, Başlat  ➜",
               WIZ_BG_DUGME_TAMAM);

      if(atlaGoster)
         Dugme("btn_atla",
               m_startX + WIZ_GENISLIK - 120,
               dugY, 100, 32,
               "Atla",
               WIZ_BG_DUGME_ATLA);

      // "Bir daha gösterme" checkbox metni (sol alt)
      Metin("chk_txt",
            m_startX + 16, dugY + 8,
            (m_tekrarGosterme ? "☑" : "☐") + " Bu ekranı bir daha gösterme",
            WIZ_DIM, 8, "Segoe UI");
   }

   //====================================================================
   //  ADIM 1 — BAĞLANTI KONTROLÜ
   //====================================================================
   bool Adim1Ciz()
   {
      IcerikTemizle();
      IlerlemeGoster(1);

      int cx = m_startX + 20;
      int cy = m_startY + 75;
      int sa = 20;  // Satır aralığı

      IcMetin("baslik1", cx, cy,
              "Adım 1/4: Bağlantı kontrol ediliyor...",
              WIZ_MAVI, 10, "Segoe UI Bold");
      cy += sa + 5;

      bool bagliMi    = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
      bool otomatikMi = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
      bool hesapIzniMi= (bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
      bool tamam = true;

      // Bağlantı durumu
      if(bagliMi)
         IcMetin("b1", cx, cy, "✅ Sunucu bağlantısı aktif", WIZ_YESIL);
      else
      {
         IcMetin("b1", cx, cy, "❌ Sunucuya bağlantı yok!", WIZ_KIRMIZI);
         cy += sa;
         IcMetin("b1c1", cx + 10, cy,
                 "Çözüm: İnternet bağlantınızı kontrol edin,", WIZ_TURUNCU, 8);
         cy += 16;
         IcMetin("b1c2", cx + 10, cy,
                 "MT5'i kapatıp yeniden açın.", WIZ_TURUNCU, 8);
         tamam = false;
      }
      cy += sa;

      // Otomatik işlem
      if(otomatikMi)
         IcMetin("b2", cx, cy, "✅ Otomatik işlem aktif", WIZ_YESIL);
      else
      {
         IcMetin("b2", cx, cy, "❌ Otomatik işlem kapalı!", WIZ_KIRMIZI);
         cy += sa;
         IcMetin("b2c1", cx + 10, cy,
                 "Çözüm: MT5 araç çubuğunda 'Otomatik İşlem'", WIZ_TURUNCU, 8);
         cy += 16;
         IcMetin("b2c2", cx + 10, cy,
                 "düğmesine tıklayın — yeşil renkte olmalı.", WIZ_TURUNCU, 8);
         tamam = false;
      }
      cy += sa;

      // Hesap işlem izni
      if(hesapIzniMi)
         IcMetin("b3", cx, cy, "✅ Hesap işlem iznine sahip", WIZ_YESIL);
      else
      {
         IcMetin("b3", cx, cy, "❌ Bu hesapta işlem izni yok!", WIZ_KIRMIZI);
         cy += sa;
         IcMetin("b3c1", cx + 10, cy,
                 "Çözüm: Broker'ınızla iletişime geçin veya", WIZ_TURUNCU, 8);
         cy += 16;
         IcMetin("b3c2", cx + 10, cy,
                 "doğru hesabı seçtiğinizden emin olun.", WIZ_TURUNCU, 8);
         tamam = false;
      }

      // Genel sonuç satırı
      cy += sa + 5;
      if(tamam)
         IcMetin("sonuc1", cx, cy,
                 "Tüm bağlantı kontrolleri başarılı.", WIZ_YESIL, 9, "Segoe UI Bold");
      else
         IcMetin("sonuc1", cx, cy,
                 "Sorunları düzelttikten sonra EA'yı yeniden başlatın.", WIZ_SARI, 8);

      DugmeleriCiz(tamam, true);
      ChartRedraw(m_grafik);
      return tamam;
   }

   //====================================================================
   //  ADIM 2 — HESAP KONTROLÜ
   //====================================================================
   bool Adim2Ciz()
   {
      IcerikTemizle();
      IlerlemeGoster(2);

      int cx = m_startX + 20;
      int cy = m_startY + 75;
      int sa = 20;

      IcMetin("baslik2", cx, cy,
              "Adım 2/4: Hesap bilgileri kontrol ediliyor...",
              WIZ_MAVI, 10, "Segoe UI Bold");
      cy += sa + 5;

      bool demoMu   = (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO);
      double bakiye = AccountInfoDouble(ACCOUNT_BALANCE);
      long kaldirac = AccountInfoInteger(ACCOUNT_LEVERAGE);
      string para   = AccountInfoString(ACCOUNT_CURRENCY);

      // Hesap türü
      if(demoMu)
         IcMetin("h1", cx, cy, "✅ Demo Hesap — Güvenli test modu", WIZ_YESIL);
      else
      {
         IcMetin("h1", cx, cy, "⚠️ Canlı Hesap tespit edildi!", WIZ_TURUNCU);
         cy += sa;
         IcMetin("h1c1", cx + 10, cy,
                 "Robotu ilk kez çalıştırıyorsunuz.", WIZ_SARI, 8);
         cy += 16;
         IcMetin("h1c2", cx + 10, cy,
                 "Önce DEMO hesapta test etmenizi şiddetle tavsiye ederiz.", WIZ_SARI, 8);
         cy += 16;
         IcMetin("h1c3", cx + 10, cy,
                 "Demo hesap açmak ücretsiz ve risksizdir.", WIZ_DIM, 8);
      }
      cy += sa + 4;

      // Bakiye
      string bakiyeTxt = "Hesap Bakiyesi: " +
                         DoubleToString(bakiye, 2) + " " + para;
      IcMetin("h2", cx, cy, bakiyeTxt, WIZ_METIN);
      cy += sa;

      // Kaldıraç
      IcMetin("h3", cx, cy,
              "Kaldıraç: 1:" + IntegerToString(kaldirac),
              (kaldirac > 400 ? WIZ_TURUNCU : WIZ_METIN));
      if(kaldirac > 400)
      {
         cy += sa;
         IcMetin("h3c", cx + 10, cy,
                 "Yüksek kaldıraç riski artırır. Dikkatli olun.", WIZ_TURUNCU, 8);
      }

      DugmeleriCiz(true, true);
      ChartRedraw(m_grafik);
      return true;  // Hesap adımı her zaman devam eder (uyarı bilgilendirme amaçlı)
   }

   //====================================================================
   //  ADIM 3 — AYAR ÖZETİ
   //====================================================================
   bool Adim3Ciz(double riskYuzdesi, string sembol)
   {
      IcerikTemizle();
      IlerlemeGoster(3);

      int cx = m_startX + 20;
      int cy = m_startY + 75;
      int sa = 18;

      IcMetin("baslik3", cx, cy,
              "Adım 3/4: Ayarlarınız kontrol ediliyor...",
              WIZ_MAVI, 10, "Segoe UI Bold");
      cy += sa + 8;

      IcMetin("ozet_hdr", cx, cy, "Mevcut Ayarlarınız:", WIZ_METIN, 9, "Segoe UI Bold");
      cy += 16;
      IcMetin("ozet_cizgi", cx, cy,
              "─────────────────────────────────────────", WIZ_DIM, 8);
      cy += 14;

      // Risk seviyesi
      string riskSeviyesi;
      color  riskRengi;
      if(riskYuzdesi <= 1.0)
         { riskSeviyesi = "Düşük ✅ (önerilen)";  riskRengi = WIZ_YESIL; }
      else if(riskYuzdesi <= 2.0)
         { riskSeviyesi = "Orta ✅";               riskRengi = WIZ_YESIL; }
      else if(riskYuzdesi <= 3.0)
         { riskSeviyesi = "Yüksek ⚠️";            riskRengi = WIZ_SARI;  }
      else
         { riskSeviyesi = "Çok Yüksek ⚠️";        riskRengi = WIZ_KIRMIZI; }

      IcMetin("a1", cx, cy, "Risk Seviyesi     : ", WIZ_DIM);
      IcMetin("a1v", cx + 130, cy, riskSeviyesi, riskRengi);
      cy += sa;

      string riskPct = "%" + DoubleToString(MathMin(riskYuzdesi, 2.0), 1);
      color  riskPctRenk = (riskYuzdesi <= 2.0) ? WIZ_YESIL : WIZ_TURUNCU;
      IcMetin("a2", cx, cy, "İşlem Başına Risk : ", WIZ_DIM);
      IcMetin("a2v", cx + 130, cy, riskPct, riskPctRenk);
      cy += sa;

      // Sembol
      IcMetin("a3", cx, cy, "Parite            : ", WIZ_DIM);
      IcMetin("a3v", cx + 130, cy, sembol + " ✅", WIZ_YESIL);
      cy += sa;

      // Zaman dilimi
      IcMetin("a4", cx, cy, "Zaman Dilimi      : ", WIZ_DIM);
      IcMetin("a4v", cx + 130, cy, "1 Saat (H1) ✅", WIZ_YESIL);
      cy += sa;

      // Bildirimler
      bool telefonAktif = (bool)TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED);
      string bildTxt = telefonAktif ? "Açık ✅" : "Kapalı (isteğe bağlı)";
      color  bildRenk = telefonAktif ? WIZ_YESIL : WIZ_DIM;
      IcMetin("a5", cx, cy, "Bildirimler       : ", WIZ_DIM);
      IcMetin("a5v", cx + 130, cy, bildTxt, bildRenk);
      cy += 14;

      IcMetin("ozet_cizgi2", cx, cy,
              "─────────────────────────────────────────", WIZ_DIM, 8);
      cy += 14;

      // Tehlikeli ayar uyarısı
      if(riskYuzdesi > 5.0)
      {
         IcMetin("uyari", cx, cy,
                 "⚠️ Risk %5'in üzerinde! Başlangıç için %1-2 önerilir.",
                 WIZ_KIRMIZI, 8, "Segoe UI Bold");
         cy += sa;
         IcMetin("uyari2", cx, cy,
                 "EA maksimum %2 ile sınırlayacak.", WIZ_TURUNCU, 8);
      }
      else
         IcMetin("uyari", cx, cy,
                 "Bu ayarlar güvenli başlangıç için uygundur.", WIZ_YESIL, 9);

      DugmeleriCiz(true, false);
      ChartRedraw(m_grafik);
      return true;
   }

   //====================================================================
   //  ADIM 4 — HAZIR
   //====================================================================
   void Adim4Ciz(string destekLinki = "")
   {
      IcerikTemizle();
      IlerlemeGoster(4);

      int cx = m_startX + 20;
      int cy = m_startY + 75;
      int sa = 20;

      IcMetin("baslik4", cx, cy,
              "Adım 4/4: Her şey hazır!",
              WIZ_YESIL, 11, "Segoe UI Bold");
      cy += sa + 8;

      IcMetin("hzr1", cx, cy,
              "Robot çalışmaya başlıyor...", WIZ_METIN, 9, "Segoe UI Bold");
      cy += sa + 4;

      IcMetin("hzr2", cx, cy,
              "İlk işlem için uygun piyasa koşulları bekleniyor.", WIZ_METIN);
      cy += sa;
      IcMetin("hzr3", cx, cy,
              "Bu süre birkaç dakika ile birkaç saat arasında", WIZ_DIM, 8);
      cy += 16;
      IcMetin("hzr4", cx, cy,
              "değişebilir — bu tamamen normaldir.", WIZ_DIM, 8);
      cy += sa + 4;

      IcMetin("hzr5", cx, cy,
              "Panel sağ üst köşede sistemi takip edebilirsiniz.", WIZ_METIN);
      cy += sa;

      if(destekLinki != "")
      {
         IcMetin("hzr6", cx, cy, "Destek: " + destekLinki, WIZ_MAVI, 8);
         cy += sa;
      }

      // Büyük "Tamam, Başlat" düğmesi
      int dugW = 200;
      Dugme("btn_tamam",
            m_startX + WIZ_GENISLIK / 2 - dugW / 2,
            m_startY + WIZ_YUKSEKLIK - 55,
            dugW, 36,
            "Tamam, Başlat  ➜",
            WIZ_BG_DUGME_TAMAM);

      // "Bir daha gösterme" checkbox
      Metin("chk_txt",
            m_startX + 16,
            m_startY + WIZ_YUKSEKLIK - 46,
            (m_tekrarGosterme ? "☑" : "☐") + " Bu ekranı bir daha gösterme",
            WIZ_DIM, 8, "Segoe UI");

      ChartRedraw(m_grafik);
   }

   //------------------------------------------------------------------
   // Grafik boyutunu al ve sihirbazı ortaya konumlandır
   //------------------------------------------------------------------
   void BaslangicKonumuHesapla()
   {
      int grafW = (int)ChartGetInteger(m_grafik, CHART_WIDTH_IN_PIXELS);
      int grafH = (int)ChartGetInteger(m_grafik, CHART_HEIGHT_IN_PIXELS);
      m_startX  = MathMax(10, (grafW - WIZ_GENISLIK)  / 2);
      m_startY  = MathMax(10, (grafH - WIZ_YUKSEKLIK) / 2);
   }

   //------------------------------------------------------------------
   // GlobalVariable'a kaydet
   //------------------------------------------------------------------
   void GVKaydet(int adim, bool tamamlandi)
   {
      GlobalVariableSet(WIZ_GV_ADIM,       (double)adim);
      GlobalVariableSet(WIZ_GV_TAMAMLANDI, tamamlandi ? 1.0 : 0.0);
      GlobalVariablesFlush();  // Diske yaz — elektrik kesilse bile kaybolmaz
   }

public:
   //------------------------------------------------------------------
   // Kurucu
   //------------------------------------------------------------------
   CWizard()
      : m_grafik(WIZ_GRAFIK),
        m_mevcutAdim(0),
        m_tekrarGosterme(false),
        m_tamamlandi(false),
        m_startX(10), m_startY(10) {}

   //------------------------------------------------------------------
   // KurulumGerekliMi: Sihirbazın çalışması gerekiyor mu?
   // Daha önce tamamlandıysa false döndürür
   //------------------------------------------------------------------
   bool KurulumGerekliMi()
   {
      if(!GlobalVariableCheck(WIZ_GV_TAMAMLANDI)) return true;
      double deger = GlobalVariableGet(WIZ_GV_TAMAMLANDI);
      return (deger < 1.0);
   }

   //------------------------------------------------------------------
   // Calistir: Sihirbazı sırayla adım adım çalıştırır
   // riskYuzdesi ve sembol CKernel'den geçirilir
   // Döndürür: true → kurulum tamam, EA başlayabilir
   //           false → sorun var veya kullanıcı iptal etti
   //------------------------------------------------------------------
   bool Calistir(double riskYuzdesi, string sembol, string destekLinki = "")
   {
      BaslangicKonumuHesapla();
      CerceveCiz();
      ChartRedraw(m_grafik);

      // ADIM 1
      m_mevcutAdim = 1;
      GVKaydet(1, false);
      bool adim1Tamam = Adim1Ciz();
      Sleep(WIZ_ADIM_BEKLEME);

      if(!adim1Tamam)
      {
         // Bağlantı sorunu var — sihirbazı aç bırak, kullanıcı dügmeye bassın
         // Gerçek tıklama akışı OnChartEvent üzerinden yönetilir (aşağıda)
         return false;
      }

      // ADIM 2
      m_mevcutAdim = 2;
      GVKaydet(2, false);
      Adim2Ciz();
      Sleep(WIZ_ADIM_BEKLEME);

      // ADIM 3
      m_mevcutAdim = 3;
      GVKaydet(3, false);
      Adim3Ciz(riskYuzdesi, sembol);
      Sleep(WIZ_ADIM_BEKLEME);

      // ADIM 4
      m_mevcutAdim = 4;
      GVKaydet(4, false);
      Adim4Ciz(destekLinki);
      // Adım 4'te kullanıcı "Tamam" düğmesine basana kadar beklenir (ChartEvent ile)

      return false; // OnChartEvent "Tamam" aldıktan sonra true döner
   }

   //------------------------------------------------------------------
   // OnChartEvent: Düğme tıklamalarını işle
   // Döndürür:
   //   0 → hiçbir şey
   //   1 → sihirbaz tamamlandı, EA başlayabilir
   //  -1 → kritik hata — EA başlamamalı
   //------------------------------------------------------------------
   int OlayIsle(const int id, const long lp, const double dp, const string sp)
   {
      if(id != CHARTEVENT_OBJECT_CLICK) return 0;

      // "Bir daha gösterme" checkbox'ı — toggle
      if(sp == N("chk_txt"))
      {
         m_tekrarGosterme = !m_tekrarGosterme;
         // Etiketi yenile
         ObjectSetString(m_grafik, N("chk_txt"), OBJPROP_TEXT,
                         (m_tekrarGosterme ? "☑" : "☐") +
                         (string)" Bu ekranı bir daha gösterme");
         ChartRedraw(m_grafik);
         return 0;
      }

      // "Atla" düğmesi — bir sonraki adıma geç
      if(sp == N("btn_atla"))
      {
         ObjectSetInteger(m_grafik, N("btn_atla"), OBJPROP_STATE, false);
         m_mevcutAdim++;
         if(m_mevcutAdim > 4)
         {
            Kapat(true);
            return 1;
         }
         // Bir sonraki adımı çiz
         return 0;
      }

      // "Tamam, Başlat" düğmesi
      if(sp == N("btn_tamam"))
      {
         ObjectSetInteger(m_grafik, N("btn_tamam"), OBJPROP_STATE, false);

         if(m_mevcutAdim < 4)
         {
            // Henüz 4. adımda değilsek bir sonraki adıma geç
            m_mevcutAdim++;
            return 0;
         }

         // 4. adımda "Tamam" → tamamlandı
         Kapat(true);
         return 1;
      }

      return 0;
   }

   //------------------------------------------------------------------
   // Kapat: Tüm WIZ_ nesnelerini sil, GlobalVariable'ı güncelle
   //------------------------------------------------------------------
   void Kapat(bool basarili)
   {
      if(basarili)
      {
         GVKaydet(4, true);
         if(m_tekrarGosterme)
         {
            // Kalıcı olarak kapat — GlobalVariable'ı sabit 1.0 bırak
            Print("CWizard: Kullanıcı 'bir daha gösterme' seçti — sihirbaz kalıcı kapatıldı.");
         }
         m_tamamlandi = true;
         Print("CWizard: Kurulum tamamlandı.");
      }
      else
      {
         GVKaydet(m_mevcutAdim, false);
      }

      // Tüm WIZ_ nesnelerini tek seferde sil
      ObjectsDeleteAll(m_grafik, WIZ_ONEK);
      ChartRedraw(m_grafik);
   }

   //------------------------------------------------------------------
   // KurulumSifirla: Sihirbazı bir sonraki açılışta tekrar göster
   // (Test veya yeniden kurulum için)
   //------------------------------------------------------------------
   void KurulumSifirla()
   {
      if(GlobalVariableCheck(WIZ_GV_TAMAMLANDI))
         GlobalVariableDel(WIZ_GV_TAMAMLANDI);
      if(GlobalVariableCheck(WIZ_GV_ADIM))
         GlobalVariableDel(WIZ_GV_ADIM);
      GlobalVariablesFlush();
      Print("CWizard: Kurulum sıfırlandı — sihirbaz bir sonraki başlatmada açılacak.");
   }

   //------------------------------------------------------------------
   // Erişiciler
   //------------------------------------------------------------------
   bool   Tamamlandi()    const { return m_tamamlandi;  }
   int    MevcutAdim()    const { return m_mevcutAdim;  }
   bool   TekrarGosterme()const { return m_tekrarGosterme; }
};
