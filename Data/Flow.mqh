//+------------------------------------------------------------------+
//| Data/Flow.mqh                                                    |
//| Classificacao do lado agressor de cada negocio (delta).          |
//|                                                                  |
//| Depende de: Config/Inputs.mqh, Core/Globals.mqh.                 |
//|                                                                  |
//| Duas fontes possiveis:                                           |
//|  1. Flags TICK_FLAG_BUY / TICK_FLAG_SELL da corretora (ideal).   |
//|  2. Regra de cotacao: negocio no ask = comprador agressor,       |
//|     no bid = vendedor agressor, no meio = pela variacao do       |
//|     ultimo preco negociado.                                      |
//|                                                                  |
//| ICS_DELTA_AUTO usa (1) e cai para (2) quando o tick nao traz     |
//| flag nenhuma. Esta e a parte mais sensivel a qualidade dos dados |
//| do simbolo - ver o diagnostico em Runtime/BarProcessor.mqh.      |
//+------------------------------------------------------------------+
#ifndef __ICSM_FLOW_MQH__
#define __ICSM_FLOW_MQH__

//+------------------------------------------------------------------+
//| Lado agressor pela regra de cotacao                              |
//+------------------------------------------------------------------+
int QuoteSide(const MqlTick &t)
{
   if(t.bid <= 0 || t.ask <= 0 || t.ask < t.bid) return 0;
   if(t.last >= t.ask) return 1;
   if(t.last <= t.bid) return -1;
   if(g_lastTradePrice > 0)
   {
      if(t.last > g_lastTradePrice) return 1;
      if(t.last < g_lastTradePrice) return -1;
      return g_lastSide;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Lado agressor conforme InpDeltaMode. Atualiza o ultimo preco e   |
//| o ultimo lado conhecido (usados pelo fallback acima).            |
//+------------------------------------------------------------------+
int TickSide(const MqlTick &t)
{
   bool b = (t.flags & TICK_FLAG_BUY)  != 0;
   bool s = (t.flags & TICK_FLAG_SELL) != 0;
   int side = 0;
   if(InpDeltaMode == ICS_DELTA_QUOTE || (InpDeltaMode == ICS_DELTA_AUTO && !b && !s))
      side = QuoteSide(t);
   else if(b && !s) side = 1;
   else if(s && !b) side = -1;
   else side = 0;                      // ambos: negocio sem agressor claro
   g_lastTradePrice = t.last;
   if(side != 0) g_lastSide = side;
   return side;
}

#endif // __ICSM_FLOW_MQH__
//+------------------------------------------------------------------+
