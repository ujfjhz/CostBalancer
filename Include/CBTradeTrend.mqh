//+------------------------------------------------------------------+
//|                                                      CBClose.mq4 |
//|                                                      ArchestMage |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "ArchestMage"
#property link      ""
#include <CBTradeCommon.mqh>

int lastTrend=0;    //上一个趋势
int test=5;

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

//主动stop,否则修改其stoplevel
void modifyStopLevel()
{
int total=OrdersTotal();
for(int pos=0;pos<total;pos++)
 {
   if(OrderSelect(pos,SELECT_BY_POS)==true)
   {
   if(OrderSymbol() !=Symbol()  || OrderMagicNumber()!=MAGICNUMBER)// Don't handle other symbols and other timeframes.
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
   
   double lotToOpen=calculatePosition();
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
      int retryCount=0;
      while(true)
      {
         retryCount=retryCount+1;
         if(retryCount>10)
         {
            log_err("Retry count reach the max, break it.");
            break;
         }
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
                  Sleep(500);                         // Simple solution            
                  RefreshRates();                     // Update data  
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
            break;
         }
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
   if(OrderSymbol() !=Symbol()  || OrderMagicNumber()!=MAGICNUMBER)// Don't handle other symbols.
   {
      continue;
   }

   if(OrderType()== OP_BUY){
      if(trend<0){
         closeSelectedTicket();
      }
   }else if(OrderType()== OP_SELL){
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