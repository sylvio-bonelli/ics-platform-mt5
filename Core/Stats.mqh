//+------------------------------------------------------------------+
//| Core/Stats.mqh                                                   |
//| Contadores nomeados usados pelo funil e pelo resumo final.       |
//|                                                                  |
//| Depende de: Core/Globals.mqh.                                    |
//|                                                                  |
//| Sao pares de arrays (nomes[], contagens[]) em vez de um mapa     |
//| porque MQL5 nao tem dicionario nativo e o volume de chaves e     |
//| pequeno (dezenas), entao a busca linear e irrelevante.           |
//+------------------------------------------------------------------+
#ifndef __ICSM_STATS_MQH__
#define __ICSM_STATS_MQH__

//+------------------------------------------------------------------+
//| Incrementa o contador da chave, criando-a se necessario          |
//+------------------------------------------------------------------+
void CountIn(string &names[], int &cnts[], string key)
{
   int j = -1;
   for(int x = 0; x < ArraySize(names); x++)
      if(names[x] == key) { j = x; break; }
   if(j < 0)
   {
      j = ArraySize(names);
      ArrayResize(names, j + 1);
      ArrayResize(cnts, j + 1);
      names[j] = key;
      cnts[j]  = 0;
   }
   cnts[j]++;
}

//+------------------------------------------------------------------+
//| Le o contador da chave (0 se nunca ocorreu)                      |
//+------------------------------------------------------------------+
int CountOf(string &names[], int &cnts[], string key)
{
   for(int x = 0; x < ArraySize(names); x++)
      if(names[x] == key) return cnts[x];
   return 0;
}

//+------------------------------------------------------------------+
//| Quebra a string de motivos ("a | b (detalhe)") e contabiliza     |
//| cada motivo separadamente, descartando o detalhe entre parenteses|
//+------------------------------------------------------------------+
void CountReasons(string why)
{
   string parts[];
   ushort sep = StringGetCharacter("|", 0);
   int k = StringSplit(why, sep, parts);
   for(int i = 0; i < k; i++)
   {
      string p = parts[i];
      StringTrimLeft(p);
      StringTrimRight(p);
      int q = StringFind(p, " (");
      if(q > 0) p = StringSubstr(p, 0, q);
      if(p == "") continue;
      int j = -1;
      for(int x = 0; x < ArraySize(g_rsnName); x++)
         if(g_rsnName[x] == p) { j = x; break; }
      if(j < 0)
      {
         j = ArraySize(g_rsnName);
         ArrayResize(g_rsnName, j + 1);
         ArrayResize(g_rsnCnt, j + 1);
         g_rsnName[j] = p;
         g_rsnCnt[j]  = 0;
      }
      g_rsnCnt[j]++;
   }
}

#endif // __ICSM_STATS_MQH__
//+------------------------------------------------------------------+
