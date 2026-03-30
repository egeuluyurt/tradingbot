//+------------------------------------------------------------------+
//|  TradingBot.mq5 — Ana Dosya                                      |
//|  Görev: EA giriş noktaları (OnInit/OnDeinit/OnTick/OnChartEvent) |
//|         ve CKernel merkezi yönetici sınıfı                       |
//+------------------------------------------------------------------+
#property copyright "TradingBot"
#property version   "1.00"
#property strict

//--- Modüller
#include "CSignal.mqh"
#include "CRisk.mqh"
#include "CTrade.mqh"
#include "CPanel.mqh"
#include "CNotify.mqh"
#include "CWizard.mqh"

//====================================================================
//  KULLANICI PARAMETRELERİ
//====================================================================
input group  "=== Genel Ayarlar ==="
input ulong  InpSihirliSayi   = 20250101;    // Magic Number (her EA için benzersiz)
input string InpSembol        = "";          // Sembol (boş = grafik sembolü)

input group  "=== Risk Ayarları ==="
input double InpRiskYuzdesi   = 1.0;        // Risk yüzdesi (%1 önerilen, maks %2)

//====================================================================
//  BROKER SEMBOL ÇÖZÜCÜ
//  EURUSD → EURUSD.pro → EURUSD.m sırasıyla dener
//====================================================================
string SembolCoz(string istenen)
{
   if(istenen == "") istenen = _Symbol;   // Grafik sembolünü kullan

   // Zaten geçerliyse direkt döndür
   if(SymbolSelect(istenen, true) && SymbolInfoInteger(istenen, SYMBOL_TRADE_MODE) != 0)
      return istenen;

   // Ek uzantıları dene
   string ekler[] = {".pro", ".m", ".r", ".c", ".i", ".PRO", ".M"};
   for(int i = 0; i < ArraySize(ekler); i++)
   {
      string denenen = istenen + ekler[i];
      if(SymbolSelect(denenen, true) && SymbolInfoInteger(denenen, SYMBOL_TRADE_MODE) != 0)
      {
         Print("SembolCoz: '", istenen, "' yerine '", denenen, "' kullanılıyor.");
         return denenen;
      }
   }

   // Hiçbiri bulunamazsa orijinali döndür
   Print("SembolCoz UYARI: '", istenen, "' için uyumlu sembol bulunamadı.");
   return istenen;
}

//====================================================================
//  CKERNEL — Merkezi Yönetici Sınıf
//====================================================================
class CKernel
{
private:
   CSignal*  m_sinyal;
   CRisk*    m_risk;
   CTrade*   m_trade;
   CPanel*   m_panel;
   CNotify*  m_notify;
   CWizard*  m_wizard;

   string   m_sembol;
   bool     m_hazir;
   bool     m_botAktif;      // DURDUR düğmesiyle false yapılabilir
   bool     m_wizardAktif;   // Sihirbaz ekrandayken true

public:
   CKernel() : m_sinyal(NULL), m_risk(NULL), m_trade(NULL),
               m_panel(NULL), m_notify(NULL), m_wizard(NULL),
               m_hazir(false), m_botAktif(true), m_wizardAktif(false) {}

   ~CKernel() { Deinit(); }

   //------------------------------------------------------------------
   // Init
   //------------------------------------------------------------------
   bool Init()
   {
      m_sembol = SembolCoz(InpSembol);

      Print("=== TradingBot başlatılıyor ===");
      Print("Sembol: ", m_sembol, " | Magic: ", InpSihirliSayi);

      m_sinyal  = new CSignal (m_sembol, PERIOD_H1);
      m_risk    = new CRisk   (m_sembol, InpRiskYuzdesi);
      m_trade   = new CTrade  (m_sembol, InpSihirliSayi);
      m_panel   = new CPanel  ("TBot", 5, 30);
      m_notify  = new CNotify ();
      m_wizard  = new CWizard ();

      if(!m_sinyal.Init()) { Print("HATA: CSignal başlatılamadı!"); return false; }
      if(!m_risk.Init())   { Print("HATA: CRisk başlatılamadı!");   return false; }
      if(!m_trade.Init())  { Print("HATA: CTrade başlatılamadı!");  return false; }
      if(!m_panel.Init())  { Print("HATA: CPanel başlatılamadı!");  return false; }

      // Sihirbaz gerekli mi?
      if(m_wizard.KurulumGerekliMi())
      {
         m_wizardAktif = true;
         Print("CKernel: İlk çalıştırma — kurulum sihirbazı açılıyor.");
         m_wizard.Calistir(InpRiskYuzdesi, m_sembol);
         // Asıl başlatma OnChartEvent "Tamam" tıklandıktan sonra tamamlanır
         return true;  // Init başarılı ama sihirbaz bekliyor
      }

      // Sihirbaz gerekmiyorsa direkt başlat
      return BotBaslat();
   }

   //------------------------------------------------------------------
   // BotBaslat: Sihirbaz tamamlandıktan (veya gerekmediğinde) çağrılır
   //------------------------------------------------------------------
   bool BotBaslat()
   {
      m_panel.ZorunluGuncelle(m_sembol, m_botAktif, m_risk.GunlukLimitModundaMi());
      m_panel.OlayEkle("✅ " + TimeToString(TimeCurrent(), TIME_MINUTES) + " Bot başlatıldı");
      m_hazir = true;
      Print("=== TradingBot hazır ===");
      return true;
   }

   //------------------------------------------------------------------
   // Deinit
   //------------------------------------------------------------------
   void Deinit()
   {
      if(m_sinyal  != NULL) { m_sinyal.Deinit(); delete m_sinyal;  m_sinyal  = NULL; }
      if(m_risk    != NULL) {                    delete m_risk;    m_risk    = NULL; }
      if(m_trade   != NULL) {                    delete m_trade;   m_trade   = NULL; }
      if(m_panel   != NULL) { m_panel.Deinit();  delete m_panel;   m_panel   = NULL; }
      if(m_notify  != NULL) {                    delete m_notify;  m_notify  = NULL; }
      if(m_wizard  != NULL) { delete m_wizard;   m_wizard  = NULL; }
      Print("=== TradingBot durduruldu ===");
   }

   //------------------------------------------------------------------
   // Tick: Her tick'te çağrılır; sinyal mantığı + panel yenileme
   //------------------------------------------------------------------
   void Tick()
   {
      if(m_wizardAktif) return;  // Sihirbaz bitene kadar işlem yapma
      if(!m_hazir) return;

      // Paneli her tick değil, sadece yeni H1 mumunda güncelle
      m_panel.Guncelle(m_sembol, m_botAktif, m_risk.GunlukLimitModundaMi());

      if(!m_botAktif) return;  // DURDUR aktifse işlem yapma

      // Paçal + günlük limit kontrolü
      double acikKar = m_trade.AcikPozisyonKari();
      if(!m_risk.IslemYapilabilirMi(acikKar)) return;

      // Sinyal al
      ENUM_SIGNAL sinyal = m_sinyal.SinyalAl();
      if(sinyal == SIGNAL_YOK) return;

      // Zaten açık pozisyon varsa yeni işlem açma
      if(m_trade.AcikPozisyonVar()) return;

      // SL fraktal bazlı
      bool alis = (sinyal == SIGNAL_AL);
      double sl = m_risk.FraktalSLHesapla(alis);

      // Giriş fiyatı
      double giris = alis
                     ? SymbolInfoDouble(m_sembol, SYMBOL_ASK)
                     : SymbolInfoDouble(m_sembol, SYMBOL_BID);

      // Tahmini CD aralığı (son 20 bar aralığının yarısı — gerçek harmonik D'de güncellenmeli)
      double yuksek = iHigh(m_sembol, PERIOD_H1,
                            iHighest(m_sembol, PERIOD_H1, MODE_HIGH, 20, 1));
      double asagi  = iLow (m_sembol, PERIOD_H1,
                            iLowest (m_sembol, PERIOD_H1, MODE_LOW,  20, 1));
      double cdAralik = (yuksek - asagi) * 0.5;

      // TP seviyeleri
      double tp1 = m_risk.TP1Hesapla(giris, alis, cdAralik);
      double tp2 = m_risk.TP2Hesapla(giris, alis, cdAralik);

      // R/Ö kontrolü (en az 1:1)
      if(!m_risk.RiskOdulUygunMu(giris, sl, tp1)) return;

      // Lot hesapla
      double lot = m_risk.LotHesapla(giris, sl);
      if(lot <= 0) return;

      // Emir aç (CTrade TP1 ile açılır; TP2 ve trailing CTrade'de yönetilir)
      bool basarili = false;
      if(alis)
         basarili = m_trade.AlisAc(lot, sl, tp1);
      else
         basarili = m_trade.SatisAc(lot, sl, tp1);

      if(basarili)
      {
         string yon  = alis ? "AL" : "SAT";
         string saat = TimeToString(TimeCurrent(), TIME_MINUTES);
         m_panel.OlayEkle("✅ " + saat + (alis ? " Alış açıldı" : " Satış açıldı"));
         m_notify.IslemAcildi(m_sembol, yon, saat);

         // Drawdown kontrolü
         double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         if(balance > 0)
         {
            double dd = (balance - equity) / balance * 100.0;
            if(dd >= 50.0) m_notify.KritikDrawdown(dd);
            else if(dd >= 30.0) m_notify.DrawdownUyarisi(dd);
         }

         // Margin kontrolü
         double marjin = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
         if(marjin > 0 && marjin < 150.0) m_notify.MarginTehlike(marjin);
      }
   }

   //------------------------------------------------------------------
   // KayipBildir / KazancBildir: CTrade'den çağrılır (işlem kapanınca)
   //------------------------------------------------------------------
   void KayipBildir(double zarar = 0)
   {
      if(m_risk   != NULL) m_risk.KayipBildir();
      if(m_panel  != NULL)
         m_panel.OlayEkle("⚠️ " + TimeToString(TimeCurrent(), TIME_MINUTES) + " İşlem zararla kapandı");

      if(m_notify != NULL)
      {
         string para = AccountInfoString(ACCOUNT_CURRENCY);
         m_notify.KorumaDevreye(m_sembol, zarar, para);

         // Ardışık kayıp bildirim eşikleri
         int kayip = (m_risk != NULL) ? m_risk.GunlukKayip() : 0;
         if(kayip >= 5)       m_notify.BesArdasiKayip();
         else if(kayip >= 3)  m_notify.UcArdasiKayip();
      }
   }

   void KazancBildir(double kar = 0)
   {
      if(m_risk   != NULL) m_risk.KazancBildir();
      if(m_panel  != NULL)
         m_panel.OlayEkle("✅ " + TimeToString(TimeCurrent(), TIME_MINUTES) + " İşlem kârla kapandı");

      if(m_notify != NULL)
      {
         string para = AccountInfoString(ACCOUNT_CURRENCY);
         m_notify.KarHedefi(m_sembol, kar, para);
      }
   }

   //------------------------------------------------------------------
   // ChartEvent: Panel düğmeleri
   //------------------------------------------------------------------
   void ChartEvent(const int id, const long lp, const double dp, const string sp)
   {
      // Sihirbaz aktifse olayları önce sihirbaza gönder
      if(m_wizardAktif && m_wizard != NULL)
      {
         int wSonuc = m_wizard.OlayIsle(id, lp, dp, sp);
         if(wSonuc == 1)   // Sihirbaz tamamlandı
         {
            m_wizardAktif = false;
            BotBaslat();
         }
         return;  // Panel olaylarını sihirbaz açıkken işleme
      }

      if(m_panel == NULL) return;

      int sonuc = m_panel.OlayIsle(id, lp, dp, sp);

      if(sonuc == 1)   // DURDUR onaylandı
      {
         m_botAktif = false;
         m_panel.OlayEkle("■ " + TimeToString(TimeCurrent(), TIME_MINUTES) + " Bot durduruldu");
         m_panel.ZorunluGuncelle(m_sembol, m_botAktif, m_risk.GunlukLimitModundaMi());
         Print("CKernel: Bot kullanıcı tarafından durduruldu.");
      }
      else if(sonuc == 2)   // TÜM KAPAT onaylandı
      {
         m_trade.TumPozisyonlariKapat();
         m_panel.OlayEkle("⚠️ " + TimeToString(TimeCurrent(), TIME_MINUTES) + " Tüm pozisyonlar kapatıldı");
         Print("CKernel: Tüm pozisyonlar kullanıcı isteğiyle kapatıldı.");
      }
   }
};

//====================================================================
//  GLOBAL KERNEL NESNESİ
//====================================================================
CKernel* kernel = NULL;

//====================================================================
//  EA GİRİŞ NOKTALARI
//====================================================================

int OnInit()
{
   kernel = new CKernel();
   if(!kernel.Init())
   {
      delete kernel;
      kernel = NULL;
      return INIT_FAILED;
   }
   return INIT_SUCCEEDED;
}

void OnDeinit(const int neden)
{
   if(kernel != NULL)
   {
      delete kernel;
      kernel = NULL;
   }
}

void OnTick()
{
   if(kernel != NULL)
      kernel.Tick();
}

void OnChartEvent(const int id, const long &lp, const double &dp, const string &sp)
{
   if(kernel != NULL)
      kernel.ChartEvent(id, lp, dp, sp);
}
