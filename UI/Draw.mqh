//+------------------------------------------------------------------+
//| UI/Draw.mqh                                                      |
//| Objetos graficos: marcadores, linhas de nivel e retangulo da zona|
//|                                                                  |
//| Depende de: Core/Globals.mqh.                                    |
//|                                                                  |
//| Todos os objetos usam o prefixo "ICS_" para permitir limpeza em  |
//| bloco. Nada aqui altera o estado do setup - e so visualizacao.   |
//| Se g_draw for false, todas as funcoes retornam imediatamente.    |
//+------------------------------------------------------------------+
#ifndef __ICSM_DRAW_MQH__
#define __ICSM_DRAW_MQH__

//+------------------------------------------------------------------+
//| Seta / simbolo em um ponto do grafico                            |
//+------------------------------------------------------------------+
void DrawMark(datetime t, double p, int code, color clr, string tip, bool below)
{
   if(!g_draw) return;
   string name = "ICSM_M" + IntegerToString(g_objN++);
   if(!ObjectCreate(0, name, OBJ_ARROW, 0, t, p)) return;
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, below ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
}

//+------------------------------------------------------------------+
//| Linha horizontal limitada no tempo (entrada, stop, alvo)         |
//+------------------------------------------------------------------+
void DrawLevel(datetime t0, datetime t1, double p, color clr, ENUM_LINE_STYLE style, string tip)
{
   if(!g_draw) return;
   string name = "ICSM_L" + IntegerToString(g_objN++);
   if(!ObjectCreate(0, name, OBJ_TREND, 0, t0, p, t1, p)) return;
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
}

//+------------------------------------------------------------------+
//| Retangulo da zona institucional corrente.                        |
//| isFinal = true pinta em cinza (zona ja encerrada).               |
//| O objeto e recriado a cada atualizacao porque a zona cresce.     |
//+------------------------------------------------------------------+
void DrawZone(bool isFinal)
{
   if(!g_draw) return;
   string name = "ICSM_Z" + IntegerToString(g_zone.id);
   ObjectDelete(0, name);
   datetime t1 = (g_zone.t1 > g_zone.t0) ? g_zone.t1 : g_zone.t0 + 300;
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, g_zone.t0, g_zone.hi, t1, g_zone.lo)) return;
   ObjectSetInteger(0, name, OBJPROP_COLOR, isFinal ? clrDimGray : clrSteelBlue);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP,
                   StringFormat("Zona Z%d  %.0f - %.0f  POC %.0f  ER %.2f  VolRel %.2f",
                                g_zone.id, g_zone.lo, g_zone.hi, g_zone.poc, g_zone.er, g_zone.relvol));
}

#endif // __ICSM_DRAW_MQH__
//+------------------------------------------------------------------+
