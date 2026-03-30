//+------------------------------------------------------------------+
//|  CPanel.mqh — Grafik Bilgi Paneli Modülü                        |
//|  Koyu tema, sağ üst köşe, 7 bilgi, IsNewBar güncellemesi        |
//+------------------------------------------------------------------+
#pragma once

//====================================================================
//  RENK PALETİ (Koyu tema — C'0x1E,0x1E,0x2E' baz)
//====================================================================
#define PANEL_BG          C'30,30,46'     // Arka plan
#define PANEL_BG2         C'40,40,60'     // Risk çubuğu zemin
#define PANEL_BORDER      C'70,70,100'    // Kenarlık
#define PANEL_BASLIK      C'200,200,230'  // Başlık yazısı
#define PANEL_NORMAL      C'180,180,210'  // Normal metin
#define PANEL_DIM         C'110,110,140'  // Soluk/olay metni
#define PANEL_YESIL       C'80,220,120'   // Kâr / aktif / güvenli
#define PANEL_KIRMIZI     C'230,80,80'    // Zarar / tehlikeli
#define PANEL_TURUNCU     C'230,150,50'   // Uyarı / dikkatli
#define PANEL_SARI        C'240,210,60'   // Dikkat
#define PANEL_DUGME_DUR   C'160,30,30'    // DURDUR düğmesi
#define PANEL_DUGME_KAP   C'160,80,20'    // TÜM KAPAT düğmesi
#define PANEL_DUGME_TXT   C'240,240,240'  // Düğme yazısı

//====================================================================
//  PANEL SABİTLERİ
//====================================================================
#define PANEL_GEN         280             // Panel genişliği
#define PANEL_SAT_Y       18              // Satır yüksekliği
#define PANEL_IC_X        10              // İç kenar boşluğu
#define PANEL_OLAY_SAYISI 3               // Gösterilecek son olay sayısı

//====================================================================
//  CPanel
//====================================================================
class CPanel
{
private:
   string   m_onEk;           // Nesne adı öneki
   long     m_grafik;
   int      m_x;              // Sağ üst köşeden X mesafesi
   int      m_y;              // Sağ üst köşeden Y mesafesi

   // Dairesel olay tamponu
   string   m_olaylar[PANEL_OLAY_SAYISI];
   int      m_olayYazici;     // Sonraki yazılacak slot

   // Yeni mum kontrolü
   datetime m_sonBarZamani;

   // Onay iletişim kutusu için bekleyen eylem
   int      m_bekleyenEylem;  // 0=yok 1=durdur 2=kapat

   //------------------------------------------------------------------
   // Nesne adı üreticileri
   //------------------------------------------------------------------
   string N(string tag) { return m_onEk + "_" + tag; }

   //------------------------------------------------------------------
   // YARDIMCI: OBJ_RECTANGLE_LABEL oluştur/güncelle
   //------------------------------------------------------------------
   void Kutu(string tag, int x, int y, int w, int h,
             color bgRenk, color kenarlık = PANEL_BORDER, int corner = CORNER_RIGHT_UPPER)
   {
      string ad = N(tag);
      if(ObjectFind(m_grafik, ad) < 0)
         ObjectCreate(m_grafik, ad, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(m_grafik, ad, OBJPROP_CORNER,      corner);
      ObjectSetInteger(m_grafik, ad, OBJPROP_XDISTANCE,   x);
      ObjectSetInteger(m_grafik, ad, OBJPROP_YDISTANCE,   y);
      ObjectSetInteger(m_grafik, ad, OBJPROP_XSIZE,       w);
      ObjectSetInteger(m_grafik, ad, OBJPROP_YSIZE,       h);
      ObjectSetInteger(m_grafik, ad, OBJPROP_BGCOLOR,     bgRenk);
      ObjectSetInteger(m_grafik, ad, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(m_grafik, ad, OBJPROP_COLOR,       kenarlık);
      ObjectSetInteger(m_grafik, ad, OBJPROP_SELECTABLE,  false);
      ObjectSetInteger(m_grafik, ad, OBJPROP_HIDDEN,      true);
      ObjectSetInteger(m_grafik, ad, OBJPROP_ZORDER,      0);
   }

   //------------------------------------------------------------------
   // YARDIMCI: OBJ_LABEL oluştur/güncelle
   //------------------------------------------------------------------
   void Metin(string tag, int x, int y, string txt, color renk,
              int boyut = 9, string font = "Segoe UI",
              int corner = CORNER_RIGHT_UPPER)
   {
      string ad = N(tag);
      if(ObjectFind(m_grafik, ad) < 0)
      {
         ObjectCreate(m_grafik, ad, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(m_grafik, ad, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(m_grafik, ad, OBJPROP_HIDDEN,     true);
         ObjectSetInteger(m_grafik, ad, OBJPROP_ZORDER,     1);
      }
      ObjectSetInteger(m_grafik, ad, OBJPROP_CORNER,    corner);
      ObjectSetInteger(m_grafik, ad, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_grafik, ad, OBJPROP_YDISTANCE, y);
      ObjectSetString (m_grafik, ad, OBJPROP_TEXT,      txt);
      ObjectSetInteger(m_grafik, ad, OBJPROP_COLOR,     renk);
      ObjectSetInteger(m_grafik, ad, OBJPROP_FONTSIZE,  boyut);
      ObjectSetString (m_grafik, ad, OBJPROP_FONT,      font);
   }

   //------------------------------------------------------------------
   // Risk çubuğu: dolgulu dikdörtgen
   //------------------------------------------------------------------
   void RiskCubuguCiz(double drawdownYuzde)
   {
      int barY    = 148;          // Sağ üst köşeden Y mesafesi
      int barTam  = PANEL_GEN - 2 * PANEL_IC_X;
      int barDolu = (int)MathRound(barTam * MathMin(drawdownYuzde / 100.0, 1.0));

      color dolguRenk;
      string etiket;
      if(drawdownYuzde < 30.0)
         { dolguRenk = PANEL_YESIL;    etiket = "■ Güvenli"; }
      else if(drawdownYuzde < 60.0)
         { dolguRenk = PANEL_SARI;     etiket = "■ Dikkatli"; }
      else
         { dolguRenk = PANEL_KIRMIZI;  etiket = "■ Tehlikeli"; }

      // Zemin çubuğu
      Kutu("risk_zemin", PANEL_IC_X + 1, barY, barTam, 10, PANEL_BG2);
      // Dolgu çubuğu
      if(barDolu > 0)
         Kutu("risk_dolgu", PANEL_IC_X + 1, barY, barDolu, 10, dolguRenk, dolguRenk);
      else
         Kutu("risk_dolgu", PANEL_IC_X + 1, barY, 1, 10, PANEL_BG2, PANEL_BG2);

      // Etiket
      string riskTxt = etiket + " (" + DoubleToString(drawdownYuzde, 1) + "%)";
      Metin("risk_etiket", PANEL_IC_X + 1, barY + 12, riskTxt,
            dolguRenk, 8, "Segoe UI");
   }

   //------------------------------------------------------------------
   // Düğme çiz (OBJ_BUTTON)
   //------------------------------------------------------------------
   void Dugme(string tag, int x, int y, int w, int h,
              string txt, color bg, color txtRenk = PANEL_DUGME_TXT)
   {
      string ad = N(tag);
      if(ObjectFind(m_grafik, ad) < 0)
         ObjectCreate(m_grafik, ad, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(m_grafik, ad, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
      ObjectSetInteger(m_grafik, ad, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_grafik, ad, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_grafik, ad, OBJPROP_XSIZE,     w);
      ObjectSetInteger(m_grafik, ad, OBJPROP_YSIZE,     h);
      ObjectSetString (m_grafik, ad, OBJPROP_TEXT,      txt);
      ObjectSetInteger(m_grafik, ad, OBJPROP_BGCOLOR,   bg);
      ObjectSetInteger(m_grafik, ad, OBJPROP_COLOR,     txtRenk);
      ObjectSetInteger(m_grafik, ad, OBJPROP_FONTSIZE,  9);
      ObjectSetString (m_grafik, ad, OBJPROP_FONT,      "Segoe UI Bold");
      ObjectSetInteger(m_grafik, ad, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(m_grafik, ad, OBJPROP_ZORDER,    2);
   }

   //------------------------------------------------------------------
   // Sabit çerçeve ve başlığı bir kez çiz
   //------------------------------------------------------------------
   void CerceveCiz()
   {
      int panelH = 300;   // Toplam panel yüksekliği

      // Arka plan
      Kutu("bg", 1, 1, PANEL_GEN, panelH, PANEL_BG);
      // Başlık şeridi
      Kutu("baslik_bg", 1, 1, PANEL_GEN, 24, C'50,50,80');

      // Başlık metni
      Metin("baslik", PANEL_GEN - PANEL_IC_X - 2, 6,
            "TradingBot v1.0",
            PANEL_BASLIK, 10, "Segoe UI Bold");

      // Bölüm ayraçları (çizgi görünümlü ince dikdörtgenler)
      Kutu("sep1", 1,  67,  PANEL_GEN, 1, PANEL_BORDER, PANEL_BORDER);  // Durum altı
      Kutu("sep2", 1,  99,  PANEL_GEN, 1, PANEL_BORDER, PANEL_BORDER);  // P/Z altı
      Kutu("sep3", 1, 170,  PANEL_GEN, 1, PANEL_BORDER, PANEL_BORDER);  // Risk altı
      Kutu("sep4", 1, 200,  PANEL_GEN, 1, PANEL_BORDER, PANEL_BORDER);  // Açık işlem altı
      Kutu("sep5", 1, 255,  PANEL_GEN, 1, PANEL_BORDER, PANEL_BORDER);  // Olaylar altı

      // Düğmeler
      int dugW  = (PANEL_GEN - 3 * PANEL_IC_X) / 2;
      int dugY  = 263;
      Dugme("dur_btn",   PANEL_IC_X + 1,           dugY, dugW, 24, "DURDUR",     PANEL_DUGME_DUR);
      Dugme("kapat_btn", PANEL_IC_X + dugW + PANEL_IC_X + 1, dugY, dugW, 24, "TÜM KAPAT", PANEL_DUGME_KAP);
   }

   //------------------------------------------------------------------
   // Yeni mum mu? (IsNewBar yardımcısı)
   //------------------------------------------------------------------
   bool YeniBarMi(string sembol)
   {
      datetime barZamani = iTime(sembol, PERIOD_H1, 0);
      if(barZamani != m_sonBarZamani)
      {
         m_sonBarZamani = barZamani;
         return true;
      }
      return false;
   }

   //------------------------------------------------------------------
   // Onay mesajı göster
   //------------------------------------------------------------------
   bool OnayAl(string mesaj)
   {
      int sonuc = MessageBox(mesaj, "TradingBot — Onay", MB_YESNO | MB_ICONQUESTION);
      return (sonuc == IDYES);
   }

public:
   //------------------------------------------------------------------
   // Kurucu
   //------------------------------------------------------------------
   CPanel(string onEk = "TBot", int x = 5, int y = 30)
      : m_onEk(onEk), m_x(x), m_y(y),
        m_olayYazici(0), m_sonBarZamani(0), m_bekleyenEylem(0)
   {
      m_grafik = ChartID();
      for(int i = 0; i < PANEL_OLAY_SAYISI; i++)
         m_olaylar[i] = "";
   }

   //------------------------------------------------------------------
   // Init
   //------------------------------------------------------------------
   bool Init()
   {
      CerceveCiz();
      ChartRedraw(m_grafik);
      Print("CPanel başlatıldı — sağ üst köşe, genişlik: ", PANEL_GEN);
      return true;
   }

   //------------------------------------------------------------------
   // Deinit: Tüm panel nesnelerini sil
   //------------------------------------------------------------------
   void Deinit()
   {
      // Öneke göre tüm nesneleri sil
      for(int i = ObjectsTotal(m_grafik, 0, -1) - 1; i >= 0; i--)
      {
         string ad = ObjectName(m_grafik, i, 0, -1);
         if(StringFind(ad, m_onEk + "_") == 0)
            ObjectDelete(m_grafik, ad);
      }
      ChartRedraw(m_grafik);
      Print("CPanel kapatıldı — tüm nesneler silindi.");
   }

   //------------------------------------------------------------------
   // Olay Ekle: circular buffer'a son olayı yaz
   //------------------------------------------------------------------
   void OlayEkle(string olay)
   {
      m_olaylar[m_olayYazici % PANEL_OLAY_SAYISI] = olay;
      m_olayYazici++;
   }

   //------------------------------------------------------------------
   // Guncelle: Her yeni H1 mumunda çağrılır
   //
   // sembol            — işlem sembolü
   // gunlukLimitModu   — true → GÜNLÜK LİMİT modu
   // botAktif          — false → durduruldu
   //------------------------------------------------------------------
   void Guncelle(string sembol,
                 bool   botAktif,
                 bool   gunlukLimitModu)
   {
      // Sadece yeni mumda güncelle
      if(!YeniBarMi(sembol)) return;

      // --- 1. DURUM SATIRI (Y≈30) ---
      string durumTxt;
      color  durumRenk;
      if(gunlukLimitModu)
         { durumTxt = "▲ Günlük Limit Doldu — Yarın devam"; durumRenk = PANEL_TURUNCU; }
      else if(!botAktif)
         { durumTxt = "■ Durduruldu";                        durumRenk = PANEL_KIRMIZI; }
      else
         { durumTxt = "● Aktif — Çalışıyor";                 durumRenk = PANEL_YESIL;   }

      Metin("durum", PANEL_GEN - PANEL_IC_X - 2, 30,
            durumTxt, durumRenk, 9, "Segoe UI");

      // --- 2. GÜNLÜK KÂR/ZARAR (Y≈50, büyük font) ---
      double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double gunlukPZ = equity - balance;
      string para     = AccountInfoString(ACCOUNT_CURRENCY);

      string pzIsaret  = (gunlukPZ >= 0) ? "+" : "";
      string pzTxt     = pzIsaret + DoubleToString(gunlukPZ, 2) + " " + para;
      color  pzRenk    = (gunlukPZ >= 0) ? PANEL_YESIL : PANEL_KIRMIZI;

      Metin("pz_etiket", PANEL_GEN - PANEL_IC_X - 2, 72,
            "Günlük K/Z", PANEL_DIM, 8, "Segoe UI");
      Metin("pz_deger",  PANEL_GEN - PANEL_IC_X - 2, 82,
            pzTxt, pzRenk, 14, "Segoe UI Bold");

      // --- 3. RİSK ÇUBUĞU (Y≈148) ---
      double maxBalance = 0;
      // Basit drawdown: bakiyeye göre equity düşüşü yüzdesi
      double drawdown = (balance > 0 && equity < balance)
                        ? ((balance - equity) / balance) * 100.0
                        : 0.0;
      Metin("risk_baslik", PANEL_GEN - PANEL_IC_X - 2, 134,
            "Risk Durumu", PANEL_DIM, 8, "Segoe UI");
      RiskCubuguCiz(drawdown);

      // --- 4. AÇIK İŞLEM ÖZETİ (Y≈175) ---
      int    acikSayi = PositionsTotal();
      double acikKar  = 0;
      for(int i = 0; i < acikSayi; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == sembol)
            acikKar += PositionGetDouble(POSITION_PROFIT);
      }
      string karIsaret = (acikKar >= 0) ? "+" : "";
      string acikTxt   = "Açık İşlem: " + IntegerToString(acikSayi) +
                         "  —  " + karIsaret + DoubleToString(acikKar, 2) + " " + para;
      color  acikRenk  = (acikKar >= 0) ? PANEL_YESIL : PANEL_KIRMIZI;

      Metin("acik_ozet", PANEL_GEN - PANEL_IC_X - 2, 177,
            acikTxt, acikRenk, 9, "Segoe UI");

      // --- 5. SON OLAYLAR (Y≈207, küçük font, gri) ---
      Metin("olay_baslik", PANEL_GEN - PANEL_IC_X - 2, 204,
            "Son Olaylar", PANEL_DIM, 8, "Segoe UI");

      for(int i = 0; i < PANEL_OLAY_SAYISI; i++)
      {
         // Okunma sırası: en yeni en üstte
         int idx = ((m_olayYazici - 1 - i) % PANEL_OLAY_SAYISI + PANEL_OLAY_SAYISI) % PANEL_OLAY_SAYISI;
         string olay = (m_olaylar[idx] != "") ? m_olaylar[idx] : "—";
         Metin("olay_" + IntegerToString(i),
               PANEL_GEN - PANEL_IC_X - 2,
               215 + i * PANEL_SAT_Y,
               olay, PANEL_DIM, 8, "Segoe UI");
      }

      ChartRedraw(m_grafik);
   }

   //------------------------------------------------------------------
   // OnChartEvent: Düğme tıklamalarını işle
   // Bu metodu TradingBot.mq5 → OnChartEvent içinden çağır
   //
   // Döndürür:
   //   0 = hiçbir şey olmadı
   //   1 = kullanıcı DURDUR onayladı
   //   2 = kullanıcı TÜM KAPAT onayladı
   //------------------------------------------------------------------
   int OlayIsle(const int id, const long lparam, const double dparam, const string sparam)
   {
      if(id != CHARTEVENT_OBJECT_CLICK) return 0;

      if(sparam == N("dur_btn"))
      {
         // Düğmeyi hemen serbest bırak
         ObjectSetInteger(m_grafik, N("dur_btn"), OBJPROP_STATE, false);
         if(OnayAl("Botu durdurmak istediğinizden emin misiniz?"))
            return 1;
         return 0;
      }

      if(sparam == N("kapat_btn"))
      {
         ObjectSetInteger(m_grafik, N("kapat_btn"), OBJPROP_STATE, false);
         if(OnayAl("Tüm açık pozisyonları kapatmak istediğinizden emin misiniz?"))
            return 2;
         return 0;
      }

      return 0;
   }

   //------------------------------------------------------------------
   // Zorunlu güncelleme (yeni bar beklenmeden — ilk tick)
   //------------------------------------------------------------------
   void ZorunluGuncelle(string sembol, bool botAktif, bool gunlukLimitModu)
   {
      m_sonBarZamani = 0;   // Bayrağı sıfırla, güncellemeye zorla
      Guncelle(sembol, botAktif, gunlukLimitModu);
   }
};
