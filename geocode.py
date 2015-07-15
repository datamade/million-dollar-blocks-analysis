import psycopg2
import requests
import json
import usaddress

PG_HOST="127.0.0.1"
PG_USER="postgres"
PG_DB="jail"
PG_PORT="5433"

DB_CONN_STR = 'host={0} dbname={1} user={2} port={3}'\
    .format(PG_HOST, PG_DB, PG_USER, PG_PORT)

def getRecords():
    sel = ''' 
    select
        p.street_address
    from people as p 
    join charges as c 
        on c.case_number = p.case_number 
    join addresses as a 
        on a.raw_address = p.street_address 
    where p.city_state like %s 
        and a.status = %s 
        and c.charge_disp IN (%s,%s,%s,%s) 
    group by p.street_address, p.city_state
    '''
    params = ('CHICAGO%','U',
        'DEF SENTENCED ILLINOIS DOC', 
        'DEF SENT TO LIFE IMPRISONMENT', 
        'DEF SENT TO INDETERMINATE TERM', 
        'DEF SENTENCED TO DEATH',)
    conn = psycopg2.connect(DB_CONN_STR)
    curs = conn.cursor()
    rows = curs.execute(sel, params)
    for row in curs.fetchall():
        yield row

def geocode(address):
    url = 'https://geomap.ffiec.gov/FFIECGeocMap/GeocodeMap1.aspx/GetGeocodeData'
    headers = {'content-type': 'application/json; charset=utf-8'}
    params = {'sSingleLine': '{0} Chicago, IL'.format(address), 'iCensusYear': "2014"}
    r = requests.post(url, headers=headers, data=json.dumps(params))
    return r.json()

if __name__ == "__main__":
    import time
    for row in getRecords():
        parsed_address = usaddress.parse(row[0])
        add = ' '.join([component for component, label in parsed_address \
                if label in ['AddressNumber', 'StreetNamePreDirectional', 'StreetName']])
        response = geocode(add)
        latitude = response['d']['sLatitude']
        longitude = response['d']['sLongitude']
        formatted_address = response['d']['sMatchAddr']
        raw_address = row[0]
        if latitude and longitude:
            print raw_address
            ins = '''
                INSERT INTO addresses (
                    status,
                    formatted_address,
                    raw_address,
                    source, 
                    latitude,
                    longitude
                ) VALUES (%s, %s, %s, %s, %s, %s)
                '''
            conn = psycopg2.connect(DB_CONN_STR)
            curs = conn.cursor()
            curs.execute(ins, 
                ('M',formatted_address,row[0],'geocoder',latitude, longitude))
            conn.commit()
            time.sleep(5)


