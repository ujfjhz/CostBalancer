//+------------------------------------------------------------------+
//|                                                      CBClose.mq4 |
//|                                                      ArchestMage |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "ArchestMage"
#property link      ""
#define MAGICNUMBER 34
extern int slippage=13; //单位为point(0.00001)

//趋势策略的变量们
int lastTrend=0;    //上一个趋势
int test=5;

//惯性策略的变量们
int inertiaPerioid=-1;   //受惯性影响的期限
int inertiaTakeprofit=10;  //惯性策略的主动take profit

//cutail策略的变量们
extern double cutailTPfactor=1.0;   //影响因子

//趋势策略的trade
void tradeTrend()
{
   //交易前先刷新价格
    RefreshRates();
   
   int trend = analyseTrend();
   
   if(trend==0)
   {
      modifyStopLevel();
   }else{
      if(lastTrend==0){
         checkForClose(trend);
         checkForOpen(trend);
      }else{
         if(trend*lastTrend < 0)
         {
            if(MathAbs(trend)>=8){
                checkForClose(trend);
                checkForOpen(trend);
            }else{
               modifyStopLevel();
            }
         }else{
            modifyStopLevel();
         }
      }
   }
   
   lastTrend=trend;
}

//收割上涨(看空时则是下跌)的尾巴
//原理：在连续3次上涨等条件后，仍然上涨的概率的期望大于50%；看空时同理。
//交易细节：在满足条件后，开单，设置较小的止盈止损点，让市场平仓。
//止损点最小为5。止损点设为前3bar的(open-low)的最大值;看空时为(high-open)的最大值。
//止盈点设为前3bar的利润点平均值
void tradeCutail()
{
   //交易前先刷新价格
   RefreshRates();

   int posLiveTime = getPosLiveTime();//该货币对已有仓位的存在时间，0表示无仓位
   if(posLiveTime>0){
      if(posLiveTime>(1500)){//每个仓位当达到30分钟还未自动平仓时，主动平仓。这里是15分钟曲线，用25区分
         closeAll();
         log_info("The position's life is exeeding 1500 senconds,close it.");
      }
   }else{
      int istail = analyseTail();//1为上涨的tail,-1为下跌的tail,0为非tail
      openTail(istail);
   }
}

//惯性策略的trade
//在惯性的影响范围内，超过inertiaTakeprofit则自动平，否则在惯性的结尾强制平。
void tradeInertia()
{
   //交易前先刷新价格
    RefreshRates();
   
   int trend = analyseInertia();
   
   inertiaPerioid--;
   
   if(inertiaPerioid>=0){//大于0表示在惯性的影响范围内
      
      int total=OrdersTotal();
      for(int pos=0;pos<total;pos++)
       {
        if(OrderSelect(pos,SELECT_BY_POS)==true)
        {
         if(OrderSymbol() !=Symbol())// Don't handle other symbols.
         {
            continue;
         }
         
         double thisProfitPoint=OrderProfit()/OrderLots();

         if(OrderMagicNumber()==MAGICNUMBER){
            if(inertiaPerioid==0 || thisProfitPoint>=inertiaTakeprofit){
               closeSelectedTicket();
            }
         }

        }else
        {
            log_err("orderselect failed :"+GetLastError());
        }
       }
      
   }else if(inertiaPerioid<-5){//避开上个影响
      if(MathAbs(trend)>=8){
          checkForClose(trend);
          checkForOpen(trend);
          if(MathAbs(trend)>9){
            inertiaPerioid=5;
          }else{
            inertiaPerioid=3;
          }
      }
   }
   

   
}

//主动stop,否则修改其stoplevel
void modifyStopLevel()
{
int total=OrdersTotal();
for(int pos=0;pos<total;pos++)
 {
  if(OrderSelect(pos,SELECT_BY_POS)==true)
  {
   if(OrderSymbol() !=Symbol())// Don't handle other symbols.
   {
      continue;
   }
   
   if(isPositiveStop())
   {
      //主动止损
      closeSelectedTicket();
      log_info("I've stop level for "+OrderTicket()+" positively.");
   }else
   {
      double newStopLoss=analyseNewStopLoss();
      double newTakeProfit=analyseNewTakeProfit();
      
      if(newStopLoss!=OrderStopLoss() || newTakeProfit!=OrderTakeProfit())
      {
         if(OrderModify(OrderTicket(),OrderOpenPrice(),newStopLoss,newTakeProfit,0,Blue)==false)
         {
            log_err("Error: set new stop level for "+OrderTicket()+" failed! errorcode:"+GetLastError());    
         }
      }   
   }
  }else
  {
      log_err("orderselect failed :"+GetLastError());
  }
 }
}

//获得当前货币对已有仓位的存在时间，单位为秒
//不算周六、日
int getPosLiveTime()
{
   int posLiveTime=0;
   int total=OrdersTotal();
   for(int pos=0;pos<total;pos++)
   {
     if(OrderSelect(pos,SELECT_BY_POS)==true)
     {
         if(OrderSymbol() !=Symbol())// Don't handle other symbols.
         {
            continue;
         }
         posLiveTime=TimeCurrent()-OrderOpenTime();
         break;
     }else
     {
         log_err("orderselect failed :"+GetLastError());
     }
   }
   int numWeek=MathFloor(posLiveTime/(7*24*3600));
   posLiveTime=posLiveTime-numWeek*2*24*3600;
    return(posLiveTime);
}

//获得当前货币对已有仓位的类别
//大于0表示多单，小于0表示空单，等于0表示无单
int getPosType()
{
   int posType=0;
   int total=OrdersTotal();
   for(int pos=0;pos<total;pos++)
   {
     if(OrderSelect(pos,SELECT_BY_POS)==true)
     {
         if(OrderSymbol() !=Symbol())// Don't handle other symbols.
         {
            continue;
         }
         if(OP_BUY==OrderType())
         {
            posType=1;
         }else if(OP_SELL==OrderType())
         {
            posType=-1;
         }
         break;
     }else
     {
         log_err("orderselect failed :"+GetLastError());
     }
   }
    return(posType);
}

//平掉所选仓
void closeSelectedTicket()
{
   //交易前先刷新价格
   RefreshRates();
   while(true)
   {    
      int lastError=0;
      
      if(OrderType()== OP_BUY  && OrderMagicNumber()==MAGICNUMBER){
             if(OrderClose(OrderTicket(),OrderLots(),Bid,slippage,Green)==false)
            {
               lastError=GetLastError();
            }else
            {
               log_info("Closed:"+OrderSymbol()+" ;Lots  "+OrderLots()+"; Price:"+Bid);
               break;
            }
      }
      
      if(OrderType()== OP_SELL && OrderMagicNumber()==MAGICNUMBER){
            if(OrderClose(OrderTicket(),OrderLots(),Ask,slippage,Red)==false)
            {
               lastError=GetLastError();
            }else
            {
               log_info("Closed:"+OrderSymbol()+" ;Lots  "+OrderLots()+"; Price:"+Ask);
               break;
            }
      }
      
      switch(lastError)                             // Overcomable errors        
      {         
         case 135:
            log_err("The price has changed. Retrying..");            
            RefreshRates();                     // Update data            
            continue;                           // At the next iteration         
         case 136:
            log_err("No prices. Waiting for a new tick..");            
            while(RefreshRates()==false)        // Up to a new tick               
               {
                  Sleep(1);                        // Cycle delay            
               }
            continue;                           // At the next iteration         
         case 146:
            log_err("Trading subsystem is busy. Retrying..");            
            Sleep(500);                         // Simple solution            
            RefreshRates();                     // Update data            
            continue;                           // At the next iteration        
      }      
      
      switch(lastError)                             // Critical errors        
      {         
         case 2 : 
            log_err("Common error.");            
            break;                              // Exit 'switch'         
         case 5 : 
            log_err("Outdated version of the client terminal.");            
            break;                              // Exit 'switch'         
         case 64: 
            log_err("The account is blocked.");            
            break;                              // Exit 'switch'         
         case 133:
            log_err("Trading forbidden");            
            break;                              // Exit 'switch'         
         default: 
            log_err("Occurred error :"+lastError);// Other alternatives         
            break;
      }  
   }
}

//于trend，平需平之仓
//trend策略专用
void checkForClose(int trend)
{

int total=OrdersTotal();
for(int pos=0;pos<total;pos++)
 {
  if(OrderSelect(pos,SELECT_BY_POS)==true)
  {
   if(OrderSymbol() !=Symbol())// Don't handle other symbols.
   {
      continue;
   }

   if(OrderType()== OP_BUY  && OrderMagicNumber()==MAGICNUMBER){
      if(trend<0){
         closeSelectedTicket();
      }
   }
   
   if(OrderType()== OP_SELL && OrderMagicNumber()==MAGICNUMBER){
      if(trend>0){
         closeSelectedTicket();
      }
   }
  }else
  {
      log_err("orderselect failed :"+GetLastError());
  }
 }
}

//专为Cutail策略开仓
void openTail(int istail)
{
   if(istail!=0)
   {
      double lotToOpen=analyseLotToOpen(istail);//借助trend的概念进行分析需要open的手数

      if(lotToOpen<=0)
      {
         return;
      }

      int thisTicket=0;
      while(true)
      {
         //交易前先刷新价格
         RefreshRates();
         double stopLoss=0;
         double takeprofit=0;
         double minSLDistance=50*Point;
         double maxSLDistance=180*Point;
         double minTPDistance=50*Point;
         double maxTPDistance=210*Point;
         if(istail>0)
         {
            /*
            minSLDistance=MathMax(minSLDistance,(Open[1]-Low[1]));
            minSLDistance=MathMax(minSLDistance,(Open[2]-Low[2]));
            minSLDistance=MathMax(minSLDistance,(Open[3]-Low[3]));
            */
            
            //另外一种stoploss算法，取前三的最低值
            double lowest=MathMin(Low[1],Low[2]);
            //lowest=MathMin(lowest,Low[3]);
            stopLoss=MathMin((Ask-minSLDistance),lowest);
            if(stopLoss<(Ask-maxSLDistance)){
               stopLoss=Ask-maxSLDistance;
            }
            //takeprofit=Ask+(High[1]+High[2]+High[3]-Open[1]-Open[2]-Open[3])*cutailTPfactor/3;
            takeprofit=Ask+(High[1]+High[2]-Open[1]-Open[2])*cutailTPfactor/2;
            if(takeprofit<(Ask+minTPDistance)){
               takeprofit=Ask+minTPDistance;
            }
            if(takeprofit>(Ask+maxTPDistance)){
               takeprofit=Ask+maxTPDistance;
            }
            thisTicket=OrderSend(Symbol(),OP_BUY,lotToOpen,Ask,slippage,stopLoss,takeprofit,"",MAGICNUMBER,0,Blue);
            
            //反向交易
            /*
            takeprofit=Ask-minSLDistance;
            if((High[1]+High[2]+High[3]-Open[1]-Open[2]-Open[3])/3<minSLDistance){
               stopLoss=Bid+minSLDistance;
            }else{
               stopLoss=Bid+(High[1]+High[2]+High[3]-Open[1]-Open[2]-Open[3])/3;
            }
            thisTicket=OrderSend(Symbol(),OP_SELL,lotToOpen,Bid,slippage,stopLoss,takeprofit,"",MAGICNUMBER,0,Blue);
            */
         }else if(istail<0)
         {
            /*
            minSLDistance=MathMax(minSLDistance,(High[1]-Open[1]));
            minSLDistance=MathMax(minSLDistance,(High[2]-Open[2]));
            minSLDistance=MathMax(minSLDistance,(High[3]-Open[3]));
            */
            
            //另外一种stoploss算法，取前三的最低值
            double highest=MathMax(High[1],High[2]);
            //highest=MathMax(highest,High[3]);
            stopLoss=MathMax((Bid+minSLDistance),highest);
            if(stopLoss>(Bid+maxSLDistance)){
               stopLoss=Bid+maxSLDistance;
            }
            //takeprofit=Bid-(Open[3]+Open[2]+Open[1]-Low[3]-Low[2]-Low[1])*cutailTPfactor/3;
            takeprofit=Bid-(Open[2]+Open[1]-Low[2]-Low[1])*cutailTPfactor/2;
            if(takeprofit>(Bid-minTPDistance)){
               takeprofit=Bid-minTPDistance;
            }
            if(takeprofit<(Bid-maxTPDistance)){
               takeprofit=Bid-maxTPDistance;
            }
            thisTicket=OrderSend(Symbol(),OP_SELL,lotToOpen,Bid,slippage,stopLoss,takeprofit,"",MAGICNUMBER,0,Red);
            
            //反向交易
            /*
            takeprofit=Bid+minSLDistance;
            if((Open[3]+Open[2]+Open[1]-Low[3]-Low[2]-Low[1])/3<minSLDistance){
               stopLoss=Ask-minSLDistance;
            }else{
               stopLoss=Ask-(Open[3]+Open[2]+Open[1]-Low[3]-Low[2]-Low[1])/3;
            }
            thisTicket=OrderSend(Symbol(),OP_BUY,lotToOpen,Ask,slippage,stopLoss,takeprofit,"",MAGICNUMBER,0,Red);
            */
         }
         if(thisTicket>0)
         {
            log_info("Opened order: "+thisTicket);
            break;
         }else{
            int lastError=GetLastError();                 // Failed :(      
            switch(lastError)                             // Overcomable errors        
            {         
               case 135:
                  log_err("The price has changed. Retrying..");            
                  RefreshRates();                     // Update data            
                  continue;                           // At the next iteration         
               case 136:
                  log_err("No prices. Waiting for a new tick..");            
                  while(RefreshRates()==false)        // Up to a new tick               
                     {
                        Sleep(1);                        // Cycle delay            
                     }
                  continue;                           // At the next iteration         
               case 146:
                  log_err("Trading subsystem is busy. Retrying..");            
                  Sleep(500);                         // Simple solution            
                  RefreshRates();                     // Update data            
                  continue;                           // At the next iteration        
            }      
            
            switch(lastError)                             // Critical errors        
            {         
               case 2 : 
                  log_err("Common error.");            
                  break;                              // Exit 'switch'         
               case 5 : 
                  log_err("Outdated version of the client terminal.");            
                  break;                              // Exit 'switch'         
               case 64: 
                  log_err("The account is blocked.");            
                  break;                              // Exit 'switch'         
               case 133:
                  log_err("Trading forbidden");            
                  break;                              // Exit 'switch'         
               default: 
                  log_err("Occurred error :"+lastError);// Other alternatives         
                  break;
            }      
         }
      }
   }
}

//于trend下开仓
//All trades are performed at correct prices. The execution price for each trade is calculated on the basis of the correct price of a two-way quote.
//trend策略专用
//TODO pending(计划v2.0实现)
void checkForOpen(int trend)
{
   if(trend==0)
   {
      return;
   }else{
      if(checkIsShake()){
          log_info("It's shaking now,stop opening.");
          return;
      }
   }
   
   double lotToOpen=analyseLotToOpen(trend);
   log_debug("try to open :"+lotToOpen);
   if(lotToOpen<=0)
   {
      return;
   }

   int thisTicket=0;
   if(trend!=0)
   {
      //交易前先刷新价格
      RefreshRates();
      while(true)
      {
         log_info("The request was sent to the server. Waiting for reply...");
         if(trend>0)
         {
            thisTicket=OrderSend(Symbol(),OP_BUY,lotToOpen,Ask,slippage,analyseStopLoss(trend),analyseTakeProfit(trend),"",MAGICNUMBER,0,Blue);
         }else if(trend<0)
         {
            thisTicket=OrderSend(Symbol(),OP_SELL,lotToOpen,Bid,slippage,analyseStopLoss(trend),analyseTakeProfit(trend),"",MAGICNUMBER,0,Red);
         }
         if(thisTicket>0)
         {
            log_info("Opened order: "+thisTicket);
            break;
         }else{
            int lastError=GetLastError();                 // Failed :(      
            switch(lastError)                             // Overcomable errors        
            {         
               case 135:
                  log_err("The price has changed. Retrying..");            
                  RefreshRates();                     // Update data            
                  continue;                           // At the next iteration         
               case 136:
                  log_err("No prices. Waiting for a new tick..");            
                  while(RefreshRates()==false)        // Up to a new tick               
                     {
                        Sleep(1);                        // Cycle delay            
                     }
                  continue;                           // At the next iteration         
               case 146:
                  log_err("Trading subsystem is busy. Retrying..");            
                  Sleep(500);                         // Simple solution            
                  RefreshRates();                     // Update data            
                  continue;                           // At the next iteration        
            }      
            
            switch(lastError)                             // Critical errors        
            {         
               case 2 : 
                  log_err("Common error.");            
                  break;                              // Exit 'switch'         
               case 5 : 
                  log_err("Outdated version of the client terminal.");            
                  break;                              // Exit 'switch'         
               case 64: 
                  log_err("The account is blocked.");            
                  break;                              // Exit 'switch'         
               case 133:
                  log_err("Trading forbidden");            
                  break;                              // Exit 'switch'         
               default: 
                  log_err("Occurred error :"+lastError);// Other alternatives         
                  break;
            }      
         }
      }
   }
}

//close all the positions in this Symbol.
void closeAll()
{
RefreshRates();
int total=OrdersTotal();
for(int pos=0;pos<total;pos++)
 {
  if(OrderSelect(pos,SELECT_BY_POS)==true)
  {
   if(OrderSymbol() !=Symbol())// Don't handle other symbols.
   {
      continue;
   }
   
   closeSelectedTicket();

  }else
  {
      log_err("orderselect failed :"+GetLastError());
  }
 }
 //log_debug("I've close all the tickets in "+Symbol());
}