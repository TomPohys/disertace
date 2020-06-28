/*Autor: Tomas POHANKA, University of Palacky in Olomouc, Czech Republic
Project: SAMMWAP - TACR TH03030023
*/

///////////////////////////////////////////////////////////////////////////
packetXBee* packet; 
//ID uzlu
char* NODE_ID="node_env";
//MAC adresa
char* MAC_ADDRESS="0013A20040D4B59F";

uint8_t  panID[2] = {0x12,0x34}; 
float temperatureVal;
int   batteryLevel;
char  batteryLevelString[10];
float humidityVal;

//interval zaznamu DD:hh:mm:ss
//#define GAIN  7
///////////////////////////////////////////////////////////////////////////

#include <WaspXBee802.h>
#include <WaspFrame.h>
#include <WaspSensorGas_v20.h>


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
  xbee802.setOwnNetAddress(0x00,0x04);
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
  
  xbee802.setRetries(2); 
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
  xbee802.setRTCfromMeshlium(MAC_ADDRESS);
  // poslani paketu
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
  
  RTC.ON();
  
}

///////////////////////////////////////////////////////////////////////////
void loop(){
 
 
  //Read the sensor 
  measureSensors();
  
  //Print the result through the USB
  USB.print(F("Temperature: "));
  USB.print(temperatureVal);
  USB.println(F("ºC"));
  
  USB.print(batteryLevelString); USB.println(F("%")); 
  
  USB.print(F("Humidity: "));
  USB.print(humidityVal);
  USB.println(F("%RH"));
  delay(1000);


}

void measureSensors()
{
  SensorGasv20.ON();
  delay(100); 
  temperatureVal = SensorGasv20.readValue(SENS_TEMPERATURE);
  delay(15000); 
  humidityVal = SensorGasv20.readValue(SENS_HUMIDITY);
  //Turn off the sensor board
  SensorGasv20.OFF();
  PWR.getBatteryLevel();
    // Getting Battery Level
    batteryLevel = PWR.getBatteryLevel();
    // Conversion into a string
    itoa(batteryLevel, batteryLevelString, 10);
}
