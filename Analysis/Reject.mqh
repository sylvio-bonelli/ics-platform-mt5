//+------------------------------------------------------------------+
//| Analysis/Reject.mqh                                              |
//| Reteste falho: vazamento sem fluxo + bounce que nao reconquista. |
//|                                                                  |
//| Depende de: Core/Utils.mqh, Analysis/Zone.mqh (RetireZone),      |
//|             Analysis/StateMachine.mqh (RecalcImpulse,            |
//|             RecalcPullback, MicroExtreme),                       |
//|             e do prototipo de EvaluateTrigger.                   |
//|                                                                  |
//| Por que existe: o ICS mata a zona em "saida sem fluxo". Esse    |
//| caminho e o trade de rejeicao (zona vazou, bounce nao           |
//| reconquistou). A populacao vai para o CSV como RETESTE_FALHO,   |
//| executada ou rejeitada.                                          |
//|                                                                  |
//| ICS com fluxo tem prioridade: ZoneBar chama StartBreakout        |
//| antes deste watch.                                               |
//+------------------------------------------------------------------+
#ifndef __ICSM_REJECT_MQH__
#define __ICSM_REJECT_MQH__

//+------------------------------------------------------------------+
//| Desliga o watch sem encerrar a zona (voltou para dentro).        |
//+------------------------------------------------------------------+
void CancelRejectWatch()
{
   if(!g_s.rejOn) return;
   g_s.rejOn = false;
}

//+------------------------------------------------------------------+
//| Primeira barra fora sem fluxo: arma o watch na direcao do vazamento |
//+------------------------------------------------------------------+
void StartRejectWatch(const IcsBar &b, int dir, double volRatio, double dpct)
{
   ZeroMemory(g_s);
   g_s.rejOn       = true;
   g_s.dir         = dir;
   g_s.brkSeq      = b.seq;
   g_s.brkTime     = b.t;
   g_s.brkVolRatio = volRatio;
   g_s.brkDeltaPct = dpct;
   g_s.brkLevel    = (dir > 0) ? g_zone.hi : g_zone.lo;
   g_s.origin      = g_s.brkLevel;
   g_s.impExt      = (dir > 0) ? b.h : b.l;
   g_s.impExtSeq   = b.seq;
   g_s.pbExt       = g_s.impExt;
   g_s.pbExtSeq    = b.seq;
   g_s.holdDone    = true;

   int bi = IdxOf(b.seq);
   double ext = (dir > 0) ? -1.0 : DBL_MAX;
   for(int i = bi - 1; i >= 0; i--)
   {
      if(DayStart(g_m1[i].t) != g_day) break;
      ext = (dir > 0) ? MathMax(ext, g_m1[i].h) : MathMin(ext, g_m1[i].l);
   }
   if(ext < 0 || ext == DBL_MAX) ext = 0;
   g_s.dayExtBefore = ext;

   LogEvent("VAZAMENTO", b.t, dir > 0 ? b.h : b.l, dir,
            StringFormat("Z%d vol=%sx delta=%s%%", g_zone.id, F(volRatio, 2), F(dpct, 0)));
}

//+------------------------------------------------------------------+
//| Acompanha o vazamento: bounce rumo a zona e rompimento do micro. |
//| Chamado so com InpRejectEntry e depois do teste de fluxo.        |
//+------------------------------------------------------------------+
void UpdateRejectWatch(const IcsBar &b, int dir, double volRatio, double dpct)
{
   if(!InpRejectEntry) return;
   if(g_s.rejOn && g_s.dir != dir)
      g_s.rejOn = false;
   if(!g_s.rejOn)
      StartRejectWatch(b, dir, volRatio, dpct);

   bool newExt = (dir > 0) ? (b.h > g_s.impExt) : (b.l < g_s.impExt);
   if(newExt)
   {
      if(g_s.pbQualified && b.seq > g_s.pbExtSeq)
      {
         double microN = MicroExtreme(g_s.pbExtSeq, b.seq - 1, dir);
         bool   trigN  = (dir > 0) ? (b.c > microN) : (b.c < microN);
         if(trigN)
         {
            RecalcPullback(b.seq - 1);
            RecalcImpulse();
            EvaluateTrigger(b, 3);
            return;
         }
         LogEvent("RETESTE_SEM_GATILHO", b.t, b.c, dir, StringFormat("Z%d", g_zone.id));
      }
      g_s.impExt      = (dir > 0) ? b.h : b.l;
      g_s.impExtSeq   = b.seq;
      g_s.pbQualified = false;
      RecalcImpulse();
      return;
   }

   RecalcImpulse();
   RecalcPullback();
   double leg = MathAbs(g_s.impExt - g_s.origin);
   if(leg <= 0) return;
   g_s.retr = MathAbs(g_s.impExt - g_s.pbExt) / leg;
   if(g_s.retr >= InpRejectMinRetr) g_s.pbQualified = true;
   if(!g_s.pbQualified || b.seq <= g_s.pbExtSeq)
   {
      if(b.seq - g_s.brkSeq >= InpRejectMaxBars)
         RetireZone("reteste sem gatilho");
      return;
   }

   double micro = MicroExtreme(g_s.pbExtSeq, b.seq - 1, dir);
   bool   trig  = (dir > 0) ? (b.c > micro) : (b.c < micro);
   if(trig)
   {
      RecalcPullback(b.seq - 1);
      EvaluateTrigger(b, 3);
      return;
   }
   if(b.seq - g_s.brkSeq >= InpRejectMaxBars)
      RetireZone("reteste sem gatilho");
}

#endif // __ICSM_REJECT_MQH__
//+------------------------------------------------------------------+
