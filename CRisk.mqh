//+------------------------------------------------------------------+
//|  CRisk.mqh — Risk, Lot ve Pozisyon Yönetimi Modülü              |
//|  Görev: Dinamik lot hesaplama, SL/TP yerleştirme,               |
//|         güvenlik kuralları ve kademeli kâr alma                 |
//+------------------------------------------------------------------+
#ifndef CRISK_MQH
#define CRISK_MQH

//====================================================================
//  CRisk
//====================================================================
class CRisk
{
private:
   string   m_sembol;
   double   m_riskYuzdesi;       // Normal risk (parametre, örn %1)
   double   m_maxRiskYuzdesi;    // Mutlak üst sınır (%5 sabit)
   double   m_minLot;
   double   m_maxLot;
   double   m_lotAdimi;

   // Güvenlik sayaçları
   int      m_gunlukKayipSayisi; // O gün ardışık kayıp sayısı
   bool     m_gunlukLimitModu;   // true → o gün işlem yasak
   datetime m_sonGunBaslangici;  // Sayacın sıfırlandığı gün

   //------------------------------------------------------------------
   // YARDIMCI: Equity (öz sermaye) — açık P/L dahil
   //------------------------------------------------------------------
   double Equity() const
   {
      return AccountInfoDouble(ACCOUNT_EQUITY);
   }

   //------------------------------------------------------------------
   // YARDIMCI: 1 pip için tick değeri (hesap para biriminde)
   //------------------------------------------------------------------
   double PipDegeri() const
   {
      double tikBoyutu = SymbolInfoDouble(m_sembol, SYMBOL_TRADE_TICK_SIZE);
      double tikDegeri = SymbolInfoDouble(m_sembol, SYMBOL_TRADE_TICK_VALUE);
      if(tikBoyutu <= 0) return 0;
      return (tikDegeri / tikBoyutu) * _Point;
   }

   //------------------------------------------------------------------
   // YARDIMCI: Lotu sembol kısıtlarına göre normalize et
   //------------------------------------------------------------------
   double NormalizeLot(double lot) const
   {
      if(m_lotAdimi > 0)
         lot = MathFloor(lot / m_lotAdimi) * m_lotAdimi;
      lot = MathMax(lot, m_minLot);
      lot = MathMin(lot, m_maxLot);
      return lot;
   }

   //------------------------------------------------------------------
   // YARDIMCI: Günlük sayacı sıfırla (yeni gün geldiyse)
   //------------------------------------------------------------------
   void GunlukSayaciGuncelle()
   {
      datetime simdi = TimeCurrent();
      MqlDateTime md;
      TimeToStruct(simdi, md);
      md.hour = 0; md.min = 0; md.sec = 0;
      datetime bugunBaslangici = StructToTime(md);

      if(m_sonGunBaslangici < bugunBaslangici)
      {
         m_gunlukKayipSayisi  = 0;
         m_gunlukLimitModu    = false;
         m_sonGunBaslangici   = bugunBaslangici;
         Print("CRisk: Yeni gün — günlük kayıp sayacı sıfırlandı.");
      }
   }

public:
   //------------------------------------------------------------------
   // Kurucu
   //------------------------------------------------------------------
   CRisk(string sembol, double riskYuzdesi = 1.0)
      : m_sembol(sembol),
        m_riskYuzdesi(riskYuzdesi),
        m_maxRiskYuzdesi(5.0),
        m_minLot(0), m_maxLot(0), m_lotAdimi(0),
        m_gunlukKayipSayisi(0), m_gunlukLimitModu(false),
        m_sonGunBaslangici(0) {}

   //------------------------------------------------------------------
   // Init
   //------------------------------------------------------------------
   bool Init()
   {
      m_minLot   = SymbolInfoDouble(m_sembol, SYMBOL_VOLUME_MIN);
      m_maxLot   = SymbolInfoDouble(m_sembol, SYMBOL_VOLUME_MAX);
      m_lotAdimi = SymbolInfoDouble(m_sembol, SYMBOL_VOLUME_STEP);

      if(m_minLot <= 0 || m_maxLot <= 0)
      {
         Print("CRisk HATA: Sembol lot bilgisi alınamadı — ", m_sembol);
         return false;
      }

      // Risk üst sınırını %2'ye sabitle (parametre ne olursa olsun)
      if(m_riskYuzdesi > 2.0)
      {
         Print("CRisk UYARI: Risk yüzdesi %2 ile sınırlandırıldı (istenilen: %",
               m_riskYuzdesi, ")");
         m_riskYuzdesi = 2.0;
      }

      GunlukSayaciGuncelle();

      Print("CRisk başlatıldı — Risk: %", m_riskYuzdesi,
            " | Maks: %", m_maxRiskYuzdesi,
            " | Min Lot: ", m_minLot,
            " | Max Lot: ", m_maxLot);
      return true;
   }

   //====================================================================
   //  DİNAMİK LOT HESAPLAMA
   //  Lot = (Equity × RiskYüzdesi) / (SL_Mesafe × PipDegeri)
   //====================================================================
   double LotHesapla(double girisFiyati, double stopLoss)
   {
      GunlukSayaciGuncelle();

      if(m_gunlukLimitModu)
      {
         Print("CRisk: Günlük limit modu aktif — lot 0 döndürülüyor.");
         return 0;
      }

      double slMesafe = MathAbs(girisFiyati - stopLoss);
      if(slMesafe < _Point)
      {
         Print("CRisk UYARI: SL mesafesi çok küçük, minimum lot.");
         return m_minLot;
      }

      double pipDeg = PipDegeri();
      if(pipDeg <= 0)
      {
         Print("CRisk HATA: Pip değeri hesaplanamadı.");
         return m_minLot;
      }

      double equity        = Equity();
      double riskMiktari   = equity * (m_riskYuzdesi / 100.0);

      // %2 tek işlem limiti
      double maxRiskMiktari = equity * 0.02;
      if(riskMiktari > maxRiskMiktari) riskMiktari = maxRiskMiktari;

      double lot = riskMiktari / (slMesafe * pipDeg);
      lot = NormalizeLot(lot);

      // %5 mutlak sınır kontrolü
      double lotMaxRisk = (equity * (m_maxRiskYuzdesi / 100.0)) / (slMesafe * pipDeg);
      lotMaxRisk = NormalizeLot(lotMaxRisk);
      if(lot > lotMaxRisk) lot = lotMaxRisk;

      Print("CRisk: Lot=", lot,
            " | Risk=", DoubleToString(riskMiktari, 2),
            " | SL mesafe=", DoubleToString(slMesafe / _Point, 1), " pip");
      return lot;
   }

   //====================================================================
   //  STOP LOSS YERLEŞTİRME
   //====================================================================

   //------------------------------------------------------------------
   // Harmonik SL: Fibonacci %141.4 seviyesinin bir tık dışı
   // xaAralik: XA dalgasının büyüklüğü (fiyat farkı)
   //------------------------------------------------------------------
   double HarmonikSLHesapla(double girisFiyati, bool alis, double xaAralik)
   {
      double fib1414 = xaAralik * 1.414;
      if(alis)
         return girisFiyati - fib1414 - _Point;   // Giriş altında
      else
         return girisFiyati + fib1414 + _Point;   // Giriş üstünde
   }

   //------------------------------------------------------------------
   // Trend SL: Son fraktalın dışı (H1 son 20 bar)
   //------------------------------------------------------------------
   double FraktalSLHesapla(bool alis)
   {
      ENUM_TIMEFRAMES tf = PERIOD_H1;
      int aramaBar = 20;

      if(alis)
      {
         // Alış → en yakın düşük fraktal (küçük pivot)
         double enYakinDusuk = DBL_MAX;
         for(int i = 2; i < aramaBar; i++)
         {
            double asagi = iLow(m_sembol, tf, i);
            bool fraktal = (asagi < iLow(m_sembol, tf, i-1) &&
                            asagi < iLow(m_sembol, tf, i-2) &&
                            asagi < iLow(m_sembol, tf, i+1) &&
                            asagi < iLow(m_sembol, tf, i+2));
            if(fraktal && asagi < enYakinDusuk) enYakinDusuk = asagi;
         }
         if(enYakinDusuk < DBL_MAX)
            return enYakinDusuk - 2 * _Point;
      }
      else
      {
         // Satış → en yakın yüksek fraktal
         double enYakinYuksek = 0;
         for(int i = 2; i < aramaBar; i++)
         {
            double yukari = iHigh(m_sembol, tf, i);
            bool fraktal = (yukari > iHigh(m_sembol, tf, i-1) &&
                            yukari > iHigh(m_sembol, tf, i-2) &&
                            yukari > iHigh(m_sembol, tf, i+1) &&
                            yukari > iHigh(m_sembol, tf, i+2));
            if(fraktal && yukari > enYakinYuksek) enYakinYuksek = yukari;
         }
         if(enYakinYuksek > 0)
            return enYakinYuksek + 2 * _Point;
      }

      // Fraktal bulunamazsa son barın dışı
      if(alis)
         return iLow(m_sembol, tf, 1) - 5 * _Point;
      else
         return iHigh(m_sembol, tf, 1) + 5 * _Point;
   }

   //------------------------------------------------------------------
   // Risk/Ödül Kontrolü: TP1'e göre, minimum 1:1
   // Her çağrıda detaylı log basar.
   //------------------------------------------------------------------
   bool RiskOdulUygunMu(double girisFiyati, double stopLoss, double takeProfit)
   {
      double slMesafe = MathAbs(girisFiyati - stopLoss);
      double tpMesafe = MathAbs(girisFiyati - takeProfit);

      if(slMesafe < _Point)
      {
         Print("R/R Kontrol | Risk: 0 (SL=giris) | Sonuc: REDDEDILDI (SL sifir)");
         return false;
      }

      double oran   = tpMesafe / slMesafe;
      bool   gecti  = (oran >= 1.0 - _Point);   // floating point toleransi

      double riskPips   = slMesafe / _Point;
      double kazancPips = tpMesafe / _Point;

      Print("R/R Kontrol | Risk: ", DoubleToString(riskPips, 1),
            " pip | Kazanc: ", DoubleToString(kazancPips, 1),
            " pip | Oran: ", DoubleToString(oran, 3),
            " | Sonuc: ", (gecti ? "GECTI" : "REDDEDILDI"));

      return gecti;
   }

   //====================================================================
   //  KÂR ALMA — 2 KADEMELI + TRAILING
   //====================================================================

   //------------------------------------------------------------------
   // TP Seviyeleri Hesapla — SL mesafesine göre (R/R garantili)
   // TP1 = giriş ± (SL_mesafe × 1.0)  →  1:1 minimum garantisi
   // TP2 = giriş ± (SL_mesafe × 1.5)  →  1:1.5
   // slMesafe: MathAbs(giris - stopLoss) olarak dışarıdan geçilmeli
   //------------------------------------------------------------------
   double TP1Hesapla(double girisFiyati, bool alis, double slMesafe)
   {
      if(alis) return girisFiyati + slMesafe * 1.0;
      else     return girisFiyati - slMesafe * 1.0;
   }

   double TP2Hesapla(double girisFiyati, bool alis, double slMesafe)
   {
      if(alis) return girisFiyati + slMesafe * 1.5;
      else     return girisFiyati - slMesafe * 1.5;
   }

   //------------------------------------------------------------------
   // ATR Tabanlı Trailing Stop Mesafesi (son 14 bar H1)
   //------------------------------------------------------------------
   double ATRTrailingMesafe(double carpan = 1.5)
   {
      int atrHandle = iATR(m_sembol, PERIOD_H1, 14);
      if(atrHandle == INVALID_HANDLE) return 30 * _Point;

      double atrArr[];
      ArraySetAsSeries(atrArr, true);
      if(CopyBuffer(atrHandle, 0, 1, 1, atrArr) <= 0)
      {
         IndicatorRelease(atrHandle);
         return 30 * _Point;
      }
      double atr = atrArr[0];
      IndicatorRelease(atrHandle);
      return atr * carpan;
   }

   //------------------------------------------------------------------
   // Hafta sonu trailing stop sıkılaştırma çarpanı
   // Cuma kapanışında → normal ATR çarpanını yarıya indir
   //------------------------------------------------------------------
   double TrailingCarpan()
   {
      MqlDateTime md;
      TimeToStruct(TimeCurrent(), md);
      // 5 = Cuma
      if(md.day_of_week == 5)
      {
         Print("CRisk: Cuma — trailing stop sıkılaştırıldı (çarpan 0.75).");
         return 0.75;
      }
      return 1.5;
   }

   //------------------------------------------------------------------
   // Kademeli Kapat Bilgisi:
   // Aşama 1 (TP1 vuruldu): %50 kapat + SL giriş fiyatına çek
   // Aşama 2 (TP2 vuruldu): kalan %50'nin yarısını kapat (%25 toplam)
   // Aşama 3: kalan %25'i ATR trailing ile sür
   //------------------------------------------------------------------
   double KapatilacakLot(double toplamLot, int kademe)
   {
      double lot = 0;
      switch(kademe)
      {
         case 1: lot = toplamLot * 0.50; break;  // TP1'de %50
         case 2: lot = toplamLot * 0.25; break;  // TP2'de %25
         // Kalan %25 trailing ile sürülür — otomatik kapanır
         default: lot = 0; break;
      }
      return NormalizeLot(lot);
   }

   //====================================================================
   //  GÜVENLİK KURALLARI
   //====================================================================

   //------------------------------------------------------------------
   // Kayıp Bildir: Her kaybeden işlem sonrası çağrılır
   //------------------------------------------------------------------
   void KayipBildir()
   {
      GunlukSayaciGuncelle();
      m_gunlukKayipSayisi++;
      Print("CRisk: Günlük kayıp sayısı = ", m_gunlukKayipSayisi);

      if(m_gunlukKayipSayisi >= 5)
      {
         m_gunlukLimitModu = true;
         Print("CRisk UYARI: Ardışık 5 kayıp — GÜNLÜK LİMİT MODU aktif. ",
               "Yarına kadar yeni işlem yok.");
      }
   }

   //------------------------------------------------------------------
   // Kazanç Bildir: Kazanan işlem ardışık sayacı sıfırlar
   //------------------------------------------------------------------
   void KazancBildir()
   {
      GunlukSayaciGuncelle();
      m_gunlukKayipSayisi = 0;
   }

   //------------------------------------------------------------------
   // İşlem Yapılabilir Mi? (Günlük limit + paçal kontrolü)
   // mevcutPozisyonKar: varsa açık pozisyonun kârı
   //------------------------------------------------------------------
   bool IslemYapilabilirMi(double mevcutPozisyonKar = 0)
   {
      GunlukSayaciGuncelle();

      if(m_gunlukLimitModu)
      {
         Print("CRisk: Günlük limit modu — işlem engellendi.");
         return false;
      }

      // Paçal yasağı: açık pozisyon zarardaysa yeni emir açma
      if(mevcutPozisyonKar < 0)
      {
         Print("CRisk: Zarardaki pozisyona ekleme (paçal) YASAK — işlem engellendi.");
         return false;
      }

      return true;
   }

   //------------------------------------------------------------------
   // Günlük Limit Modunda mı?
   //------------------------------------------------------------------
   bool GunlukLimitModundaMi() const { return m_gunlukLimitModu; }

   //====================================================================
   //  ERİŞİCİLER
   //====================================================================
   double RiskYuzdesi()  const { return m_riskYuzdesi; }
   double MinLot()       const { return m_minLot; }
   double MaxLot()       const { return m_maxLot; }
   int    GunlukKayip()  const { return m_gunlukKayipSayisi; }

   void RiskYuzdesiniAyarla(double yuzde)
   {
      m_riskYuzdesi = MathMin(yuzde, 2.0); // %2 tavanı koru
   }
};
#endif // CRISK_MQH
