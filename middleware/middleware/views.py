"""
Routes and views for the flask application.
"""

from datetime import datetime
from flask import render_template
from flask import request
from lorawan import app
import psycopg2
import json
import binascii
import collections

DBNAME = ""
USER = ""
HOST = ""
PASSWORD = ""


@app.route('/', methods = ['POST'])

def home():
    """Renders the home page."""
    # from sigfox 
    # {"ec": 0, "bat": 98, "data": "624c2d0000004e0000", "pluv": 0, "time": "1563533152", "ec5_1": 0, "ec5_2": 0, "s_hum": 45, "device": "", "s_temp": 76, "ec_temp": 78, "pluv_prev_hour": 0}
    if request.headers['Content-Type'] == 'application/json':
        if request.headers['auth'] == '':
            with psycopg2.connect("dbname='' user=''  host= password='' ") as con:
                cur = con.cursor()
                cur.execute("INSERT INTO public. (value) VALUES ('%s')" % (json.dumps(request.json)),)
                myjson = request.json
                time = myjson['time']
                device = myjson['device']
                rest_s = 0
                rest_t = 0
                
                for sensor in myjson:
                    if sensor == 'rest':
                        rest_s = str(myjson[sensor])[0]
                        rest_t = str(myjson[sensor])[1]
                        
                for sensor in myjson:
                    
                    if sensor not in ['time', 'device', 'data', 'rest']:
                        # v sensoru pridavam 50 aby -50 stupnu byla 0 a 50 stupnů byla 100 - aby se cisla vesla do 2B
                        value = myjson[sensor]
                        if sensor == 'TCA':
                            if value > 0 and value < 100:
                                value = float(myjson[sensor]) - 50 + float(rest_t)*0.1
                        elif sensor == 'TCB':
                            if value > 0 and value < 100:
                                value = float(myjson[sensor]) - 50 + float(rest_s)*0.1
                        
                        cur.execute("INSERT INTO public. (id_sensor, sensor, value, time) VALUES ('%s','%s', %.2f, '%s')" % (device, sensor, float(value), datetime.fromtimestamp(int(time)).strftime('%d-%m-%Y %H:%M:%S')),)
        return render_template(
            'index.html',
            title='Home Page',
            year=datetime.now().year, data = "sended"
        )

@app.route('/contact')
def contact():
    """Renders the contact page."""
    return render_template(
        'contact.html',
        title='Contact',
        year=datetime.now().year,
        message='Your contact page.'
    )