# -*- coding: utf-8 -*-


# name of table with raw data
RAW = 'raw_vota'
TABLE = 'vota'

LOG_FILE = 'vota_log.log'
DATA_FILE = r''
import json
import time
import psycopg2
import urllib2
import datetime
import calendar
import dateutil.parser as dp
import logging
import pause

import sys
import pprint


# záznam aktivity skriptu, soubor se nepřemazává
logging.basicConfig(filename=LOG_FILE, level = logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')


logging.info("spustění skriptu OWM")


try:
    conn = psycopg2.connect("dbname='' user='' host='' password=''")
    cur = conn.cursor()
except:
    logging.critical('nepripojeno k databazi localhost')

# timestamp jako primarni klic - nevznikaji duplicitni hodnoty pro cas    
cur.execute('CREATE TABLE IF NOT EXISTS %s ( id serial PRIMARY KEY, "acc_timestamp" timestamp without time zone, raw JSONB);' % (RAW, ) )

"""
cur.execute('CREATE TABLE IF NOT EXISTS %s ( id serial , "acc_timestamp" timestamp without time zone PRIMARY KEY, \
    meas_timestamp timestamp without time zone, \
    rain_g_1_tot decimal, \
    rain_g_1_del decimal, \
    rain_g_2_tot decimal, \
    rain_g_2_del decimal, \
    rain_g_3_tot decimal, \
    rain_g_3_del decimal, \
    rain_g_4_tot decimal, \
    rain_g_4_del decimal, \
    temp_1 decimal, \
    temp_2 decimal, \
    temp_3 decimal, \
    temp_4 decimal, \
    temp_5 decimal, \
    temp_6 decimal, \
    temp_7 decimal, \
    temp_8 decimal, \
    virrib_1 decimal, \
    virrib_2 decimal, \
    virrib_3 decimal, \
    virrib_4 decimal, \
    ec5_1 decimal, \
    ec5_2 decimal, \
    ec5_3 decimal, \
    ec5_4 decimal, \
    ec10_1 decimal, \
    ec10_2 decimal, \
    ec10_3 decimal, \
    ec10_4 decimal, \
    ems33_t decimal, \
    ems33_h decimal, \
    ems11_t decimal, \
    humair_t decimal, \
    humair_h decimal, \
    ucam_file text, \
    sensor text \
    );' % (TABLE, ) )
"""

cur.execute('CREATE TABLE IF NOT EXISTS %s (\
    id serial PRIMARY KEY,\
    acc_timestamp timestamp without time zone , \
    meas_timestamp timestamp without time zone, \
    sensor_type text, \
    value decimal, \
    sensor_id text);' % (TABLE,))
    
with open(DATA_FILE.encode('UTF-8')) as jfile:
    json_data = json.load(jfile)
#print len(json_data['logfile'])
#print json_data['logfile'][0]['measure'][1]['date']

#for i in xrange(len(json_data['logfile'])):
#    print json_data['logfile'][i]


acc_time = datetime.datetime.utcnow()
#print acc_time
no_date = 0
for measurement in json_data['logfile']:
    #measure_date['measure'][1]['date']
    #pprint.pprint(measurement)
    try:
        if measurement[u'info']:
            continue
    except:
        #print "neni info"
        pass
    try:
        if measurement[u'inno']:
            continue
    except:
        #print "neni inno"
        pass

    
    id = measurement['node']
    try:
        meas_timestamp = datetime.datetime.strptime(measurement['measure'][1]['date'].replace("Z",""),'%Y-%m-%dT%H:%M:%S.%f')
    except:
        no_date += 1
        continue
    cur.execute("insert into %s (acc_timestamp, raw) values ('%s', '%s');" % (RAW, acc_time, json.dumps(measurement)))
    
    multivalue = False
    for single_sensor in measurement['measure'][1]:
        #pprint.pprint(single_sensor)
        # not take as new record
        if single_sensor == "ucamII" or single_sensor == 'date':
                continue
        single_sensor_value = measurement['measure'][1][single_sensor]
        #pprint.pprint(single_sensor)

                    
        cur.execute("SELECT meas_timestamp from {} WHERE sensor_type = '{}' ORDER BY meas_timestamp DESC LIMIT 1;".format(TABLE, single_sensor))
        last_time = cur.fetchone()

        try:
            last_time_unix = calendar.timegm(last_time[0].utctimetuple())
        except:
            last_time_unix = 0
        #print last_time_unix, "vs.", calendar.timegm(meas_timestamp.utctimetuple())
        
        # jestliže poslední čas v db a nový čas není stejný
        if int(last_time_unix) != int(calendar.timegm(meas_timestamp.utctimetuple())):
        
        
            
            
                # u'EMS33': {u'hum': 0.75, u'temp': 13.08}
                # u'HumiAir9': {u'hum': 0, u'temp': 0}
            if single_sensor == u'EMS33' or single_sensor == u'HumiAir9' or single_sensor.startswith(u'RainGauge'):
                for part_signle_sensor in measurement['measure'][1][single_sensor]:
                    #print single_sensor, "vs.", part_signle_sensor
                    single_sensor_value = measurement['measure'][1][single_sensor][part_signle_sensor]
                    #print single_sensor_value
                    multi_sensor = single_sensor + "_" + part_signle_sensor
                    
                    cur.execute("insert into {0} (acc_timestamp, meas_timestamp, sensor_type, value, sensor_id) values ('{1}', '{2}', '{3}', {4}, {5});".format(TABLE, acc_time, meas_timestamp, multi_sensor, single_sensor_value, id))
                    multivalue = True
                    
                 
        

            
            # parsed data
            if not multivalue:
                cur.execute("insert into {0} (acc_timestamp, meas_timestamp, sensor_type, value, sensor_id) values ('{1}', '{2}', '{3}', {4}, {5});".format(TABLE, acc_time, meas_timestamp, single_sensor, single_sensor_value, id))
                
            #print single_sensor_value
            #pprint.pprint( measurement)

        try:
            conn.commit()
            multivalue = False
        except:
            print 'Nelze zapsat do databáze'
            logging.critical('Nelze zapsat do databáze')
print no_date
sys.exit(0)

#utc time
#meas_timestamp = datetime.datetime.strptime(json_data['logfile'][0]['measure'][1]['date'].replace("Z",""),'%Y-%m-%dT%H:%M:%S.%f')

sys.exit(0)
# json data parsing
temp = json_data["main"]["temp"]
humidity = json_data["main"]["humidity"]
pressure = json_data["main"]["pressure"]
try:
    wind_deg = json_data["wind"]["deg"]
except:
    wind_deg = "NULL"
try:
    wind_speed = json_data["wind"]["speed"]
except:
    wind_speed = "NULL"
try:
    clouds = json_data["clouds"]["all"]
except:
    clouds = "NULL"

weat_desc = json_data["weather"][0]["description"]

city_name_json = json_data["name"]
try:
    visib = json_data["visibility"]
except:
    visib = "NULL"

# jsou nová data?
cur.execute("SELECT meas_timestamp from {} WHERE sensor = '{}' ORDER BY meas_timestamp DESC LIMIT 1;".format(WEATHER_TABLE, city_name_json))
last_time = cur.fetchone()

try:
    last_time_unix = calendar.timegm(last_time[0].utctimetuple())
except:
    last_time_unix = 0

# jestliže poslední čas v db a nový čas není stejný
if int(last_time_unix) != int(json_data["dt"]):
    # raw data
    cur.execute("insert into %s (acc_timestamp, raw, server) values ('%s', '%s', '%s');" % (WEATHER_RAW, acc_time, json.dumps(json_data), WEATHER_TABLE))
    # parsed data
    cur.execute("insert into {0} (acc_timestamp, meas_timestamp, temp, humidity, pressure, wind_deg, wind_speed, clouds, weather_desc, visib, sensor) values ('{1}', '{2}', {3}, {4}, {5}, {6}, {7}, {8}, '{9}', {10}, '{11}');".format(WEATHER_TABLE, acc_time, meas_timestamp, temp, humidity, pressure, wind_deg, wind_speed, clouds, weat_desc, visib, city_name_json))
            
try:
    conn.commit()
except:
    logging.critical('Nelze zapsat do databáze')

conn.close()
logging.info('úspěšně zapsáno do databáze')
nr = next_run(datetime.datetime.now())

print "OWM - spim od UTC: " + \
    acc_time.replace(microsecond=0).isoformat(' ') + " do: " + str(nr)
logging.info("OWM - spim od UTC: " + acc_time.replace(microsecond=0).isoformat(' ') + " do: "+ str(nr))
pause.until(nr)