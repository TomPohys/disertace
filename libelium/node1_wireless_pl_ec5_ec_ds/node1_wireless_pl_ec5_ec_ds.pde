/*Autor: Tomas POHANKA, University of Palacky in Olomouc, Czech Republic
Project: SAMMWAP - TACR TH03030023
*/

///////////////////////////////////////////////////////////////////////////
const byte numReadings = 10;
unsigned int readings[numReadings], AnalogAverage = 0, averageVoltage=0;
unsigned long AnalogSampleTime, printTime, tempSampleTime, AnalogValueTotal = 0;
float EC_5_6, EC_5_6_analog, EC_5_6_eq1, EC_5_6_eq1_0_100, EC_5_7, EC_5_7_analog, EC_5_7_eq1, EC_5_7_eq1_0_100;
float read_analog6, read_analog7, sensor_volts6, sensor_volts7, VWC6, VWC7;
float EC, temperature, ECcurrent;
byte index = 0;

float pluviometer1; //mm in current hour 
float pluviometer2; //mm in previous hour
float pluviometer3; //mm in last 24 hours
int pendingPulses;

packetXBee* packet; 
//ID uzlu
char* NODE_ID="node_01";
//MAC adresa
char* MAC_ADDRESS="0013A20040D4B59F";

uint8_t  panID[2] = {0x12,0x34}; 

//interval zaznamu DD:hh:mm:ss
//#define GAIN  7
///////////////////////////////////////////////////////////////////////////

#include <WaspXBee802.h>
#include <WaspFrame.h>
#include <WaspSensorAgr_v20.h>

void sleep_until(int to_time)
{ 
  char* minutes = "";
  sprintf(minutes, "00:00:%02d:00", to_time);
  USB.print(minutes);
  SensorAgrv20.sleepAgr(minutes, RTC_ABSOLUTE, RTC_ALM1_MODE4, SOCKET0_OFF, SENS_AGR_PLUVIOMETER);
}

///////////////////////////////////////////////////////////////////////////
void setup(){
  
  // init USB port
  USB.ON();
  
  xbee802.ON();
  USB.println(NODE_ID);
  
  xbee802.setChannel(0x0C);
   /////////////////////////////////////
  // 2. set PANID
  /////////////////////////////////////
  xbee802.setPAN( panID );
  xbee802.setOwnNetAddress(0x00, 0x01);
  // check the AT commmand execution flag
  if( xbee802.error_AT == 0 ) 
  {
    USB.print(F("2. PAN ID set OK to: 0x"));
    USB.printHex( xbee802.PAN_ID[0] ); 
    USB.printHex( xbee802.PAN_ID[1] ); 
    USB.println();
  }
  else 
  {
    USB.println(F("2. Error calling 'setPAN()'"));  
  }
  
  xbee802.setRTCfromMeshlium(MAC_ADDRESS);

  xbee802.setPowerLevel(4);
  xbee802.setEncryptionMode(0);
  //xbee802.setOwnNetAddress(0x12,0x34);
  xbee802.setRetries(3); 
  xbee802.setSendingRetries(8);
  xbee802.writeValues();

  USB.println(RTC.getTime());
  frame.createFrame(ASCII);
  frame.setID(NODE_ID);	
  packet = (packetXBee*) calloc(1,sizeof(packetXBee));
  packet -> mode = UNICAST;
  
  frame.addSensor(SENSOR_STR, NODE_ID);
  //nastaveni cilovych parametru paketu
  xbee802.setDestinationParams(packet, MAC_ADDRESS, frame.buffer, frame.length); 
  
  xbee802.sendXBee(packet);

  //kontrola
  if( xbee802.error_TX == 0 ) 
  {
    USB.println(F("odeslano"));
  }
  else 
  {
    USB.println(F("chyba odeslani"));
    USB.println(xbee802.error_TX);
  }

  free(packet);
  packet = NULL;
  
  // pro DS18B20
  for (byte thisReading = 0; thisReading < numReadings; thisReading++)
    readings[thisReading] = 0;
    AnalogSampleTime=millis();
    printTime=millis();
    tempSampleTime=millis();
  
  RTC.ON();
  SensorAgrv20.ON();
  
}

///////////////////////////////////////////////////////////////////////////
void loop(){
  // mode 4 - bere minuty a sekundy, offset - přičítá k času zapnutí
  //SensorAgrv20.sleepAgr("00:00:10:00", RTC_OFFSET, RTC_ALM1_MODE4, SOCKET0_OFF, SENS_AGR_PLUVIOMETER);
  // probudit se v absolutní minute (sleep_until)
  
  if ((RTC.minute >= 0) && (RTC.minute <= 14)){sleep_until(15);}
  else{ if ((RTC.minute >= 15) && (RTC.minute <= 29)){sleep_until(30);}
        else{ if ((RTC.minute >= 30) && (RTC.minute <= 44)){sleep_until(45);}
              else{ if ((RTC.minute >= 45) && (RTC.minute <= 59)){sleep_until(0);}}
            }
      }
  USB.println(RTC.getAlarm1());
  USB.println();
  frame.createFrame(ASCII);
  
  /////////////////////////////////////////////
  // 2.1. check pluviometer interruption
  /////////////////////////////////////////////
    if( intFlag & PLV_INT)
      {
        USB.println(F("+++ PLV interruption +++"));

        pendingPulses = intArray[PLV_POS];

        USB.print(F("Number of pending pulses:"));
        USB.println( pendingPulses );

      for(int i=0 ; i<pendingPulses; i++)
        {
          // Enter pulse information inside class structure
          SensorAgrv20.storePulse();

          // decrease number of pulses
          intArray[PLV_POS]--;
        }

      // Clear flag
      intFlag &= ~(PLV_INT); 
      }
  
  /////////////////////////////////////////////
  // 2.2. check RTC interruption
  /////////////////////////////////////////////
    if(intFlag & RTC_INT)
      {
        USB.println(F("+++ RTC interruption +++"));
      
        // switch on sensor board
        SensorAgrv20.ON();
      
        RTC.ON();
        USB.print(F("Time:"));
        USB.println(RTC.getTime());        
  
        // measure sensors
        ///////////////////////////////////////////////////////////////////////////
        measureSensors();
        ///////////////////////////////////////////////////////////////////////////
        // PWR.getBatteryLevel dava jinou hodnotu, když odesílá a když měří
        frame.addSensor(SENSOR_BAT, PWR.getBatteryLevel());
        //frame.addSensor(SENSOR_SOIL1, EC_5_6_eq1_0_100);
        //frame.addSensor(SENSOR_SOIL2, EC_5_7_eq1_0_100);
        frame.addSensor(SENSOR_SOIL1, VWC6);
        frame.addSensor(SENSOR_SOIL2, VWC7);
        frame.addSensor(SENSOR_LW, ECcurrent);
        frame.addSensor(SENSOR_TCB, temperature);
        frame.addSensor(SENSOR_PLV1, pluviometer1);
        frame.addSensor(SENSOR_PLV2, pluviometer2);
        frame.addSensor(SENSOR_PLV3, pluviometer3);
        
        // zobrazeni ramce
        frame.showFrame();
        ///////////////////////////////////////////////////////////////////////////
        //send
        xbee802.ON();
        
        packet = (packetXBee*) calloc(1,sizeof(packetXBee));
        packet -> mode = UNICAST;
        //nastaveni cilovych parametru paketu
        xbee802.setDestinationParams(packet, MAC_ADDRESS, frame.buffer, frame.length); 

        // poslani paketu
        xbee802.sendXBee(packet);
        //delay(10000);
        //kontrola
        if( xbee802.error_TX == 0 ) 
        {
          USB.println(F("odeslano"));
        }
        else 
        {
          USB.println(F("chyba odeslani"));
        }
      
        free(packet);
        packet = NULL;
      
        //vypnuti komunikace
        xbee802.OFF();
              
        // Clear flag
        intFlag &= ~(RTC_INT); 
      }  
  
}

///////////////////////////////////////////////////////////////////////////
void measureSensors()
{  
    //////////////////////////////////////////////////////////////
  // EC-5 - analog6, analog7
    
    // zapnout napajeni a odecist hodnotu
    PWR.setSensorPower(SENS_3V3,SENS_ON);
    delay(10);   
    EC_5_6 = analogRead(ANALOG6);
    EC_5_7 = analogRead(ANALOG7);
    PWR.setSensorPower(SENS_3V3,SENS_OFF);
    
    /*
    // staré vypocty
    EC_5_6_analog = EC_5_6 * (float)3300/1023;
    EC_5_7_analog = EC_5_7 * (float)3300/1023;
    
    EC_5_6_eq1 = (float)1 / ((-0.0000000011057 * pow(EC_5_6_analog,3)) + (0.000003575*pow(EC_5_6_analog,2)) - (0.0039557*EC_5_6_analog) + 1.53153);
    EC_5_6_eq1_0_100 = (EC_5_6_eq1 - 1.4780392646)*6.1;
 
    EC_5_7_eq1 = (float)1 / ((-0.0000000011057 * pow(EC_5_7_analog,3)) + (0.000003575*pow(EC_5_7_analog,2)) - (0.0039557*EC_5_7_analog) + 1.53153);
    EC_5_7_eq1_0_100 = (EC_5_7_eq1 - 1.4780392646)*6.1;
    
    */
    sensor_volts6 = (float(read_analog6) * 330 / 1023);
    sensor_volts7 = (float(read_analog7) * 330 / 1023);
    
    VWC6 = ((0.0119*sensor_volts6)-0.401)*100;
    VWC7 = ((0.0119*sensor_volts7)-0.401)*100;
    
    if (VWC7 < 0.1){
      VWC7 = 0;
    };
    if (VWC6 < 0.1){
      VWC6 = 0;
    };
    
    /*
    USB.print(" EC_5_6 ");
    USB.println(EC_5_6);
    
    USB.print(" EC_5_7 ");
    USB.println(EC_5_7);
    
    USB.print(" EC_5_6_analog ");
    USB.println(EC_5_6_analog);
    
    USB.print(" EC_5_7_analog ");
    USB.println(EC_5_7_analog);
    
    USB.print(" EC_5_6_eq1 ");
    USB.println(EC_5_6_eq1);
    
    USB.print(" EC_5_6_eq1_0_100 ");
    USB.println(EC_5_6_eq1_0_100);

    USB.print(" EC_5_7_eq1 ");
    USB.println(EC_5_7_eq1);
    
    USB.print(" EC_5_7_eq1_0_100 ");
    USB.println(EC_5_7_eq1_0_100);
    */
  ////////////////////////////////////////////////////////////////
  // DFROBOT - EC, DS18B20

    for (int i=0; i<=numReadings; i++){
      
         // subtract the last reading:
        AnalogValueTotal = AnalogValueTotal - readings[index];
        
        // read from the sensor:
        PWR.setSensorPower(SENS_5V,SENS_ON);
        // pro zapnutí napajení pro pin 22,23,24
        SensorAgrv20.setSensorMode(SENS_ON, SENS_AGR_TEMPERATURE);
        delay(10);
        readings[index] = analogRead(ANALOG4);
        PWR.setSensorPower(SENS_5V,SENS_OFF);
        SensorAgrv20.setSensorMode(SENS_OFF, SENS_AGR_TEMPERATURE);
        
        // add the reading to the total:
        AnalogValueTotal = AnalogValueTotal + readings[index];
        // advance to the next position in the array:
        index = index + 1;
        // if we're at the end of the array...
        if (index >= numReadings)
        // ...wrap around to the beginning:
        index = 0;
        // calculate the average:
        AnalogAverage = AnalogValueTotal / numReadings;

        tempSampleTime=millis();
        // pro zapnutí napájení pinu 17
        SensorAgrv20.setSensorMode(SENS_ON, SENS_AGR_LDR);
        delay(10);
        temperature = Utils.readTempDS1820(DIGITAL2, true);  // read the current temperature from the  DS18B20
        SensorAgrv20.setSensorMode(SENS_OFF, SENS_AGR_LDR);

        averageVoltage=AnalogAverage*(float)4900/1558;
        
        /*
        USB.print("Analog value:");
        USB.print(AnalogAverage);   //analog average,from 0 to 1023
        USB.print("    Voltage:");
        USB.print(averageVoltage);  //millivolt average,from 0mv to 4995mV
        USB.print("mV    ");
        USB.print("temp:");
        USB.print(temperature);    //current temperature
        USB.print("^C     EC:");
        */
        
        float TempCoefficient=1.0+0.0185*(temperature-25.0);    //temperature compensation formula: fFinalResult(25^C) = fFinalResult(current)/(1.0+0.0185*(fTP-25.0));
        float CoefficientVolatge=(float)averageVoltage/TempCoefficient;   
        if(CoefficientVolatge<150)USB.println("No solution!");   //25^C 1413us/cm<-->about 216mv  if the voltage(compensate)<150,that is <1ms/cm,out of the range
        else if(CoefficientVolatge>3300)USB.println("Out of the range!");  //>20ms/cm,out of the range
        else
        { 
          if(CoefficientVolatge<=448)ECcurrent=6.84*CoefficientVolatge-64.32;   //1ms/cm<EC<=3ms/cm
          else if(CoefficientVolatge<=1457)ECcurrent=6.98*CoefficientVolatge-127;  //3ms/cm<EC<=10ms/cm
          else ECcurrent=5.3*CoefficientVolatge+2278;                           //10ms/cm<EC<20ms/cm
          ECcurrent/=1000;    //convert us/cm to ms/cm
          USB.print(ECcurrent);  //two decimal
          USB.println("ms/cm");
        }
      
    }

    // Read the pluviometer sensor
    /* WaspSensorAgr_v20cpp - line 1028 
     / calculate precipitation (mm) for indicated time period
	precipitations = pluviometerCounter * 0.2794; 
	
	return precipitations;
    */
    // 5ml na preklopeni
    pluviometer1 = SensorAgrv20.readPluviometerCurrent() / 0.2794 * 0.1075;
    pluviometer2 = SensorAgrv20.readPluviometerHour() / 0.2794 * 0.1075;
    pluviometer3 = SensorAgrv20.readPluviometerDay() / 0.2794 * 0.1075;
    /////////////////////////////////////////////////////
    // 2. USB: Print the weather values through the USB
    /////////////////////////////////////////////////////
    
    // Print the accumulated rainfall
    /*
    USB.print(F("Current hour accumulated rainfall (mm/h): "));
    USB.println( pluviometer1 );
  
    // Print the accumulated rainfall
    USB.print(F("Previous hour accumulated rainfall (mm/h): "));
    USB.println( pluviometer2 );
  
    // Print the accumulated rainfall
    USB.print(F("Last 24h accumulated rainfall (mm/day): "));
    USB.println( pluviometer3 );
    
    ////////////////////////////////////////////////////////////
    // Battery
    // Show the remaining battery level
    USB.print(F("Battery Level: "));
    USB.print(PWR.getBatteryLevel(),DEC);
    USB.print(F(" %"));
  
    // Show the battery Volts
    USB.print(F(" | Battery (Volts): "));
    USB.print(PWR.getBatteryVolts());
    USB.println(F(" V"));
    */
    
    // dulezite pro prerusovac - i kdyz je uspany a nema zadnou spotrebu
    // potřebuje nastavit na zapnuto  

    SensorAgrv20.ON();
}
