# -*- coding: utf-8 -*-
# Col1: " Virrib Avg;",
# Col2: " RH Avg;",
# Col3: " Vbatt Avg;",
# Col4: " EC5 Avg;",
# Col5: " TA Avg;",
# Col6: " RG Avg;",
# Col7: "TAin Avg;",
# Col8: "TAin Avg;"
#"10:56:00 27.05.2016"

# {
 #  6: [u'12:42:00 27.05.2016', 20.613, 34.844, 8.791, 0.964, 28.284],
 # 7: [u'14:00:00 25.11.2016', None, None, None, None, None, 0.0],
 # 8: [u'00:00:00 25.11.2016', 32.342, 87.567, 9.359, 1.049, 8.757, 0.0, 11.473],
 # 9: [u'00:00:00 04.01.2017', 31.622, 84.516, 8.796, 1.041, 0.763, 0.0, None, 1.871]
# }
ENVIRO = ''
TABLE = ''
FIRST_DATE = '20.07.2019'
START_DATE = '13.3.2017'
END_DATE = '2.9.2017'
SENSORS = ["Virrib", "HUMB", "BAT","SOIL1", "TCB", "PLV1", "TCA"]
import json
import sys
import time
import os
import psycopg2
from pprint import pprint
import urllib2
import base64
from datetime import datetime, timedelta
import logging

# záznam aktivity skriptu, soubor se nepřemazává
logging.basicConfig(filename="easylog.log", level = logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

logging.info("spustění skriptu")

try:
    # atlass postgres
    conn = psycopg2.connect("dbname='' user='' host='' password=''")
    cur = conn.cursor()
except:
    logging.critical('nepripojeno k databazi')

# timestamp jako primarni klic - nevznikaji duplicitni hodnoty pro cas    
#cur.execute('CREATE TABLE IF NOT EXISTS %s ( id serial , "timestamp" timestamp without time zone PRIMARY KEY, Virrib real, RH real, Vbatt real, EC5 real, TA real, RG real, TAin real, stanice text);' % (TABLE, ) )

cur.execute("SELECT time from data WHERE id_sensor = 'enviro' ORDER BY time DESC LIMIT 1;")

last_time = cur.fetchone()
if last_time:
    for last_record in last_time:
        # nezapisuje se pulnoční hodnota (předcházení duplicit)
        day_after_last_record = last_record + timedelta(days=1)
        
    day_after_last_record = day_after_last_record.strftime('%d.%m.%Y')
else:
    # první den měření
    day_after_last_record = FIRST_DATE

yesterday = datetime.now() - timedelta(days=1)
yesterday = yesterday.strftime('%d.%m.%Y')
today = time.strftime('%d.%m.%Y')

    

if int(day_after_last_record.split('.')[2]) >= int(yesterday.split('.')[2]):
    if int(day_after_last_record.split('.')[1]) >= int(yesterday.split('.')[1]):
        if int(day_after_last_record.split('.')[0]) > int(yesterday.split('.')[0]):
            logging.warning('Aktualni data. Není třeba spouštět skript')
      
# dateTo - bez pulnocni hodnoty. ta bude zaznamenana az nasledujici den
link = 'http://data.enviroinvest.cz/dta/GetDataJson?table&dateFrom={0}&dateTo={1}&Loc428-Col1&Loc428-Col2&Loc428-Col3&Loc428-Col4&Loc428-Col5&Loc428-Col6&Loc428-Col7&Loc428-Col8'.format(day_after_last_record, yesterday)

username = ''
password = ''

try:
    request = urllib2.Request(link)
    base64string = base64.b64encode('%s:%s' % (username, password))
    request.add_header("Authorization", "Basic %s" % base64string)   
    result = urllib2.urlopen(request)
    logging.info('připojeno k envirodata')
except:
    logging.critical('Nepřipojeni k envirodata serveru')

json_data = json.load(result)

for data in json_data['table']['data']:

    time, date = data[0].split(" ")

    # because PG9.5 need timestamp in year-month-day format, not in day.month.year format
    day,month,year = date.split('.')
    timestamp = year + '-' + month+ '-' + day + ' ' + time

    if data[1] == None and data[2] == None:
        print data
        logging.warning('Nelze zapsat ' + str(data))
        continue
        
        
    # pro libelium
    i = 1
    for sens_name in SENSORS:
        if data[i] != None:
            #print data[i]
            cur.execute("insert into data (time, sensor, value, id_sensor) values ('%s', '%s', %.2f, '%s');" % (timestamp, sens_name, data[i], ENVIRO))
        i += 1
    
    
    if len(data) == 6:
        cur.execute("insert into %s (timestamp, Virrib, RH, Vbatt, EC5, TA, stanice) values ('%s', '%s', '%s', '%s', '%s', '%s', '%s');" % (TABLE, timestamp, data[1],data[2],data[3],data[4],data[5], ENVIRO))
    elif len(data) == 7:
        cur.execute("insert into %s (timestamp, Virrib, RH, Vbatt, EC5, TA, RG, stanice) values ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s');" % (TABLE, timestamp, data[1],data[2],data[3],data[4],data[5], data[6], ENVIRO))
    elif len(data) == 8:
        cur.execute("insert into %s (timestamp, Virrib, RH, Vbatt, EC5, TA, RG, TAin, stanice) values ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s');" % (TABLE, timestamp, data[1],data[2],data[3],data[4],data[5], data[6], data[7], ENVIRO))
    elif len(data) == 9:
        cur.execute("insert into %s (timestamp, Virrib, RH, Vbatt, EC5, TA, RG, TAin, stanice) values ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s');" % (TABLE, timestamp, data[1],data[2],data[3],data[4],data[5], data[6], data[8], ENVIRO))
    else:
        #pprint('NOT possible to create correct INSERT statement')
        logging.critical('Nelze vytvořit INSERT' )
    
try:
    conn.commit()
except:
    logging.critical('Nelze zapsat do databáze')
conn.close()
logging.info('úspěšně dokončeno')