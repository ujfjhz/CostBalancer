//+------------------------------------------------------------------+
//|                                                         test.mq4 |
//|                        Copyright 2012, MetaQuotes Software Corp. |
//|                                        http://www.metaquotes.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2012, MetaQuotes Software Corp."
#property link      "http://www.metaquotes.net"
//动量模型
//建议该指标只允许运行于1分钟的timeframe上，以基于最细粒度的数据，从而真实反应市场状况
//用法：iCustom(NULL,1,"CBMomentum",Period(),0,0);	注意区别ea所运行的timeframe于indicator所运行的timeframe
#property indicator_chart_window 
#property indicator_buffers 5       // Number of buffers
#property indicator_color1 Yellow    // Line color of 0 buffer	V+
#property indicator_color2 DarkOrange//Line color of the 1st buffer	V-
#property indicator_color3 Green    // Line color of the 2nd buffer		V
#property indicator_color4 Brown    // Line color of the 3rd buffer
#property indicator_color5 Blue    // Line color of the 4rd buffer
extern int period=60;	//默认该指标用于支持60分钟曲线的交易
int periodAMA=period*4;	//用于计算加速度的时间间隔

//--------------------------------------------------------------- 2 --
int History    =1440;        // Amount of bars in calculation history

double Line_0[];   //上涨总和(Point)，V+
double Line_1[];	//下跌总和，V-
double Line_2[];	//V ：+净上涨；-净下跌
double Line_3[];   //上涨的加速度
double Line_4[];	//下跌的加速度

//--------------------------------------------------------------- 4 --
int init()                          // Special function init()  
{   
SetIndexBuffer(0,Line_0);        // Assigning an array to a buffer   
SetIndexBuffer(1,Line_1);        // Assigning an array to a buffer   
SetIndexBuffer(2,Line_2);        // Assigning an array to a buffer   
SetIndexBuffer(3,Line_3);        // Assigning an array to a buffer   
SetIndexBuffer(4,Line_4);        // Assigning an array to a buffer   

SetIndexStyle (0,DRAW_LINE,STYLE_SOLID,1);// Line style
SetIndexStyle (1,DRAW_LINE,STYLE_SOLID,1);// Line style
SetIndexStyle (2,DRAW_LINE,STYLE_SOLID,1);// Line style
SetIndexStyle (3,DRAW_LINE,STYLE_SOLID,1);// Line style
SetIndexStyle (4,DRAW_LINE,STYLE_SOLID,1);// Line style

return(0);                          // Exit the special function init()  
}

int start()                         // Special function start()  
{

int   i,                               // Bar index    
Counted_bars;                    // Amount of counted bars 
//-------------------------------------------------------------- 10 --   
Counted_bars=IndicatorCounted(); // Amount of counted bars    
i=Bars-Counted_bars-1;           // Index of the first uncounted   
if (i>History-1)                 // If too many bars ..      
i=History-1;                  // ..calculate specified amount
//-------------------------------------------------------------- 11 --   
while(i>=0)                      // Loop for uncounted bars     
{      
double VupSum=0;	//1周期内的上涨总和(>=0)
double VdownSum=0;	//1周期内的下降总和(>=0)
double VSum=0;	//1周期呈现的(>0表示上涨，<0表示下降)
int j=period;	//以交易所用的timeframe作为周期
while(j>0){
	if(Close[i+j]>Open[i+j]){
		VupSum=VupSum+High[i+j]-Low[i+j];
		VdownSum=VdownSum+High[i+j]-Close[i+j]+Open[i+j]-Low[i+j];
	}else{
		VupSum=VupSum+High[i+j]-Open[i+j]+Close[i+j]-Low[i+j];
		VdownSum=VdownSum+High[i+j]-Low[i+j];
	}
	j--;
}
Line_0[i]=VupSum/Point;
Line_1[i]=VdownSum/Point;
Line_2[i]=(Close[i+1]-Open[i+period])/Point;
Line_3[i]=(Line_0[i]-Line_0[i+periodAMA])/periodAMA;
Line_4[i]=(Line_1[i]-Line_1[i+periodAMA])/periodAMA;
i--;                          // Calculating index of the next bar      
//-------------------------------------------------------- 19 --     
}   
return(0);                          // Exit the special function start()  
}//-------------------------------------------------------------- 