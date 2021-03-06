//+------------------------------------------------------------------+
//|                                                       CBUtil.mq4 |
//|                                                      ArchestMage |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "ArchestMage"
#property link      ""
#include <CBMonitor.mqh>
extern bool debug=false;

void log_info(string content)
{
	Print(content);
}

void log_err(string content)
{
	Alert(content);
	msgReport=msgReport+"\n"+content;
}

void log_debug(string content)
{
	if(debug){
		Print(content);
	}
}

void log_fatal(string content)
{
	Alert(content);
	SendMail("[FATAL]System error.",content);
}