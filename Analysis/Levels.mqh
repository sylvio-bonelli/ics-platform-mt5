//+------------------------------------------------------------------+
//| Analysis/Levels.mqh                                              |
//| Niveis candidatos a alvo (os "obstaculos" do caminho).           |
//|                                                                  |
//| Depende de: Core/Globals.mqh, Data/VolumeProfile.mqh (ProfHVN).  |
//|                                                                  |
//| A logica do ICS e projetar o alvo no PRIMEIRO obstaculo relevante|
//| na direcao da operacao, nao em um multiplo fixo de risco. Os     |
//| candidatos sao:                                                  |
//|   - POC / VAH / VAL / maxima / minima do dia ANTERIOR            |
//|   - extremo do dia corrente antes do rompimento                  |
//|   - bordas e POC das zonas ja encerradas hoje                    |
//|   - HVNs do Volume Profile do dia (fora da zona atual)           |
//|                                                                  |
//| A escolha entre eles (primeiro estrito x primeiro que atende o   |
//| R:R) acontece em Analysis/Trigger.mqh.                           |
//+------------------------------------------------------------------+
#ifndef __ICSM_LEVELS_MQH__
#define __ICSM_LEVELS_MQH__

//+------------------------------------------------------------------+
//| Acrescenta um nivel nomeado na lista de candidatos               |
//+------------------------------------------------------------------+
void AddLvl(double &lv[], string &nm[], double p, string name)
{
   if(p <= 0) return;
   int k = ArraySize(lv);
   ArrayResize(lv, k + 1);
   ArrayResize(nm, k + 1);
   lv[k] = p;
   nm[k] = name;
}

//+------------------------------------------------------------------+
//| Monta a lista completa de candidatos a alvo para a direcao dada  |
//+------------------------------------------------------------------+
void GatherLevels(double &lv[], string &nm[], int dir)
{
   ArrayResize(lv, 0);
   ArrayResize(nm, 0);
   if(g_hasPrev)
   {
      AddLvl(lv, nm, g_prevPoc,  "POC anterior");
      AddLvl(lv, nm, g_prevVah,  "VAH anterior");
      AddLvl(lv, nm, g_prevVal,  "VAL anterior");
      AddLvl(lv, nm, g_prevHigh, "maxima anterior");
      AddLvl(lv, nm, g_prevLow,  "minima anterior");
   }
   AddLvl(lv, nm, g_s.dayExtBefore, dir > 0 ? "maxima do dia" : "minima do dia");
   for(int i = 0; i < ArraySize(g_doneHi); i++)
   {
      AddLvl(lv, nm, dir > 0 ? g_doneLo[i] : g_doneHi[i], "zona anterior");
      AddLvl(lv, nm, g_donePoc[i], "POC de zona anterior");
   }
   double h[];
   int nh = ProfHVN(h);
   for(int i = 0; i < nh; i++)
   {
      if(h[i] >= g_zone.lo - InpProfileStep && h[i] <= g_zone.hi + InpProfileStep) continue;
      AddLvl(lv, nm, h[i], "HVN do dia");
   }
}

#endif // __ICSM_LEVELS_MQH__
//+------------------------------------------------------------------+
