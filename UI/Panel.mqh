//+------------------------------------------------------------------+
//| UI/Panel.mqh                                                     |
//| Painel de texto no canto do grafico (Comment).                   |
//|                                                                  |
//| Depende de: Core/Globals.mqh, Core/Utils.mqh.                    |
//|                                                                  |
//| Chamado a cada barra M1 processada quando g_draw = true.         |
//+------------------------------------------------------------------+
#ifndef __ICSM_PANEL_MQH__
#define __ICSM_PANEL_MQH__

void UpdatePanel()
{
   string st  = (g_state == ST_IDLE) ? "sem zona" :
                (g_state == ST_ZONE && g_s.rejOn) ? "zona ativa (reteste falho)" :
                (g_state == ST_ZONE) ? "zona ativa" :
                (g_state == ST_BREAKOUT) ? "rompimento (aguardando aceitacao)" : "deslocamento / pullback";
   string ctx = (g_ctx > 0) ? "alta" : ((g_ctx < 0) ? "baixa" : "neutro");
   string z   = (g_state != ST_IDLE) ? StringFormat("Zona Z%d: %.0f - %.0f", g_zone.id, g_zone.lo, g_zone.hi) : "";
   string pb  = (g_state == ST_IMPULSE) ?
                StringFormat("Retracao: %.0f%% | pullback valido: %s", g_s.retr * 100, B(g_s.pbQualified)) : "";
   string loss = "";
   if(InpMaxLossDayBRL > 0)
      loss = StringFormat("\nPnL dia: R$ %.2f | limite: R$ %.2f%s",
                          DayPnlBRL(), InpMaxLossDayBRL,
                          g_dayLossHalt ? " | PARADO" : "");
   Comment(StringFormat("ICS Modular v%s %s\nEstado: %s\nContexto: %s\n%s\n%s\nGatilhos: %d | executados: %d%s",
                        ICSM_VERSION, InpBaseline ? "[BASELINE]" : "", st, ctx, z, pb, g_signals, g_tkN, loss));
}

#endif // __ICSM_PANEL_MQH__
//+------------------------------------------------------------------+
