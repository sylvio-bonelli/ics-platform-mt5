//+------------------------------------------------------------------+
//| Execution/Logger.mqh                                             |
//| Arquivos CSV e registro de eventos do setup.                     |
//|                                                                  |
//| Depende de: Core/Utils.mqh (WriteLine, TS, F), Core/Stats.mqh    |
//|             (CountIn), UI/Draw.mqh (DrawMark).                   |
//|                                                                  |
//| Dois arquivos sao gerados na pasta COMUM do MetaTrader           |
//| (Common\Files), o que permite abrir no Excel enquanto o teste    |
//| ainda roda:                                                      |
//|   ICS_sinais_<simbolo>_<modo>.csv   -> uma linha por gatilho     |
//|   ICS_eventos_<simbolo>_<modo>.csv  -> trilha do setup           |
//|                                                                  |
//| LogEvent tambem desenha o marcador correspondente no grafico e   |
//| alimenta o funil (CountIn), exceto durante o reprocessamento.    |
//+------------------------------------------------------------------+
#ifndef __ICSM_LOGGER_MQH__
#define __ICSM_LOGGER_MQH__

//+------------------------------------------------------------------+
//| Abre os CSV e escreve os cabecalhos                              |
//+------------------------------------------------------------------+
void OpenFiles()
{
   if(!g_files) return;
   string sfx  = InpBaseline ? "baseline" : "completo";
   if(InpRunTag != "") sfx += "_" + InpRunTag;
   string base = _Symbol + "_" + sfx;
   int flags   = FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ;
   g_fSig = FileOpen("ICS_Modular_sinais_" + base + ".csv", flags);
   g_fEvt = FileOpen("ICS_Modular_eventos_" + base + ".csv", flags);
   if(g_fSig == INVALID_HANDLE || g_fEvt == INVALID_HANDLE)
      PrintFormat("Aviso: nao foi possivel criar os CSV (erro %d)", GetLastError());
   string hdr = "id;data;hora_entrada;direcao;setup;status;motivos;score;contexto;zona_id;zona_min;zona_max;";
   hdr += "zona_barras_m5;zona_vol_rel;absorcao;teste;padrao_v;romp_vol_x;romp_delta_pct;";
   hdr += "retracao_pct;pullback_vol_ratio;pullback_delta_contra;gatilho_vol_x;gatilho_delta_pct;";
   hdr += "entrada;stop;alvo;fonte_alvo;risco_pts;retorno_pts;rr_liquido;";
   hdr += "saida_hora;saida_preco;saida_motivo;resultado_pts;resultado_R;mae_pts;mfe_pts;resultado_brl";
   WriteLine(g_fSig, hdr);
   WriteLine(g_fEvt, "hora;evento;direcao;preco;detalhes");
}

//+------------------------------------------------------------------+
//| Registra um evento do setup: CSV + contador + marcador grafico   |
//+------------------------------------------------------------------+
void LogEvent(string type, datetime t, double price, int dir, string info)
{
   string d = (dir > 0) ? "C" : ((dir < 0) ? "V" : "");
   if(!g_replay) CountIn(g_evName, g_evCnt, type);
   WriteLine(g_fEvt, TS(t) + ";" + type + ";" + d + ";" + F(price, 0) + ";" + info);
   if(!g_draw) return;
   if(type == "ROMPIMENTO")
      DrawMark(t, price, dir > 0 ? 233 : 234, dir > 0 ? clrDodgerBlue : clrOrange, type + ": " + info, dir > 0);
   else if(type == "ARMADILHA")
      DrawMark(t, price, 251, clrYellow, type + ": " + info, dir < 0);
   else if(type == "ABSORCAO")
      DrawMark(t, price, 108, clrMagenta, type + ": " + info, true);
   else if(type == "TESTE_FUNDO")
      DrawMark(t, price, 159, clrAqua, type + ": " + info, true);
   else if(type == "TESTE_TOPO")
      DrawMark(t, price, 159, clrAqua, type + ": " + info, false);
}

#endif // __ICSM_LOGGER_MQH__
//+------------------------------------------------------------------+
