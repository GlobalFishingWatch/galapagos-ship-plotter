# -*- coding: utf-8 -*-

from datetime import datetime
import re

MINUTES_HOUR=60
SECONDS_HOUR=60*60

# 180101 235959
def normalize_date(raw_date):
    only_timestamp = raw_date.strip().upper() \
                    .replace(" AM","") \
                    .replace(" PM","")
    try:
        timestamp = datetime.strptime(only_timestamp, '%y%m%d %H%M%S')
    except ValueError:
        raise
    return timestamp.strftime('%Y-%m-%dT%H:%M:%SZ')

# 0.0kt
def normalize_float(raw_float):
    try:
        #Finds double in string
        return float(re.findall('\d+[\.|,]?\d*', raw_float)[0].replace(',','.') if type(raw_float)==str else raw_float)
    except IndexError:
        return raw_float
    except ValueError:
        return raw_float

#
def normalize_degree(raw_degree):
    try:
        return float(raw_degree)
    except ValueError as err:
        if '°' in raw_degree or '\xb0' in raw_degree:
            return dms_f(raw_degree)
        else:
            raise err

def dms_f(raw_degree):
    "Converts from degree minutes and seconds to float"
    parts = re.split('[^\d\w\.]+', raw_degree.strip())
    parts_sz=len(parts)
    if parts_sz == 2:
        return float(parts[0])
    if parts_sz == 3:
        return float(parts[0]) + float(parts[1])/MINUTES_HOUR
    if parts_sz == 4:
        return float(parts[0]) + float(parts[1])/MINUTES_HOUR + float(parts[2])/SECONDS_HOUR

def normalize_latlon(raw_latlon):
    if re.match('^(\d+\.\d+[NESW])$', raw_latlon):
        dd=normalize_float(raw_latlon)
        dd*=(-1 if re.match('^(\d+\.\d+[SW])$', raw_latlon) else 1)
        return dd

def normalize_data(raw_line):
    fields=raw_line.split(';')

    default_sorted=['mmsi', 'status', 'rot', 'speed', 'latitude', 'longitude', 'course', 'heading', 'unknown_fields', 'timestamp', 'type']
    field_names={}
    i=0
    for x in default_sorted:
        field_names[x]=[fields[i]]
        i+=1

    field_names.get('rot').append(normalize_degree(field_names.get('rot')[0]))
    field_names.get('speed').append(normalize_float(field_names.get('speed')[0]))
    field_names.get('latitude').append(normalize_latlon(field_names.get('latitude')[0]))
    field_names.get('longitude').append(normalize_latlon(field_names.get('longitude')[0]))
    field_names.get('course').append(normalize_degree(field_names.get('course')[0]))
    field_names.get('heading').append(normalize_degree(field_names.get('heading')[0]))
    field_names.get('timestamp').append(normalize_date(field_names.get('timestamp')[0]))

    for name in ['mmsi','status', 'unknown_fields', 'type']:
        field_names.get(name).append(field_names.get(name)[0])

    # sort like we want to show it
    output_arr=[]
    for name in default_sorted:
        output_arr.append(str(field_names.get(name)[1]))
    output=','.join(output_arr)

    # check if there is a None
    if 'None' in output_arr:
        print(output)
        sys.exit(1)
    return output

if __name__ == '__main__':
    import sys
    args=sys.argv
    if (len(args) != 3):
        print('== The arguments must be 3')
        sys.exit(1)


    method=args[1]
    param=args[2]
    result=None
    if method == 'data':
        result = normalize_data(param)
    if method == 'date':
        result = normalize_date(param)
    if method == 'float':
        result = normalize_float(param)
    if method == 'degree':
        result = normalize_degree(param)
    if method == 'latlon':
        result = normalize_latlon(param)

    normalizers=['data', 'date', 'float', 'degree', 'latlon']
    if method not in normalizers or result == None:
        print('You must to call a method and a parameter')
        print('== Methods: ', normalizers)
        sys.exit(1)

    print result
    sys.exit(0)
