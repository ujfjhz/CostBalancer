//+------------------------------------------------------------------+
//|                                                         test.mq4 |
//|                        Copyright 2012, MetaQuotes Software Corp. |
//|                                        http://www.metaquotes.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2012, MetaQuotes Software Corp."
#property link      "http://www.metaquotes.net"

//+------------------------------------------------------------------+
//| script program start function                                    |
//+------------------------------------------------------------------+

extern string monitor="GBPJPY240";	//默认只由GBPJPY4H负责邮件发送

int monitor()
{
	//if((Symbol()+Period())==monitor && TimeMinute(Time[0])==0 && TimeDayOfWeek(Time[0])<=6 && TimeDayOfWeek(Time[0])>=2)	
   double stdDev=iStdDev(NULL,0,26,0,MODE_LWMA,PRICE_MEDIAN,0);
   Alert(stdDev);
	return(0);
}

int start()
  {
	monitor();
	return(0);
  }

