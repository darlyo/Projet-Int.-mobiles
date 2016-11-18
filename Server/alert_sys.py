import redis
import sys
import math as Math
import ast
import json

def serDatas(messageToSer):     # serialize data to json
    result = json.dumps(messageToSer)
    return result
    
 
def Distance(lat_a_degre, lon_a_degre, lat_b_degre, lon_b_degre):       # disantce between 2 given points

    if lat_a_degre.find(',') != -1:         # replace , by .
        lat_a_deg_float = lat_a_degre.replace(',','.')
    else:
        lat_a_deg_float = lat_a_degre

    if lon_a_degre.find(',') != -1:
        lon_a_def_float = lon_a_degre.replace(',','.')
    else:
         lon_a_def_float = lon_a_degre

    if lat_b_degre.find(',') != -1:
        lat_b_deg_float = lat_b_degre.replace(',','.')
    else:
        lat_b_deg_float = lat_b_degre

    if lon_b_degre.find(',') != -1:
       lon_b_deg_float = lon_b_degre.replace(',','.')
    else:
        lon_b_deg_float = lon_b_degre
    
    R = 6378000 #earth radius
 
    lat_a = Math.radians(float(lat_a_deg_float))
    lon_a = Math.radians(float(lon_a_def_float))
    lat_b = Math.radians(float(lat_b_deg_float))
    lon_b = Math.radians(float(lon_b_deg_float))
     
    d = R * (3.14159265/2 - Math.asin( Math.sin(lat_b) * Math.sin(lat_a) + Math.cos(lon_b - lon_a) * Math.cos(lat_b) * Math.cos(lat_a))) #calc distance
    return d

#sys.argv = ["alert_sys.py", "172.30.1.135", "49", "2.3", "500000"]      # comand line arg

ip = ''     #ip server
topicMessage = ''   #message content

locationLatitude = ''   
lcoationLongitude = ''
locationRadius = '' # all message in given area

if len(sys.argv) == 3:      # if user want apply a filter by topics content
    ip = sys.argv[1]
    topicMessage = sys.argv[2]  # topic content filter
    r = redis.StrictRedis(host=ip, port=6380, db=0)     # connect to redis

    p = r.pubsub()      # publisher/subscriber
    p.subscribe('App_BD')

    while(1):
         message = p.get_message()  # get a message

         if message:
            ret = ast.literal_eval(str(message['data']))    #evaluate an expression node or a Unicode or Latin-1 encoded string
            #print ret
            messageJson = serDatas(ret) # serialization json

            if message['data'] != 1:
                 if json.loads(messageJson)['contenu'].find(topicMessage) != -1:    # if content = filter
                        print json.loads(messageJson)['contenu']    
                        print json.loads(messageJson)['date_post']
    
elif len(sys.argv) == 5:    # if user want message in given area
    ip = sys.argv[1]
    locationLatitude = sys.argv[2]
    locationLongitude = sys.argv[3]
    locationRadius = sys.argv[4]
    
    r = redis.StrictRedis(host=ip, port=6380, db=0)

    p = r.pubsub()
    p.subscribe('App_BD')

    while(1):
         message = p.get_message()
         if message:
            ret = ast.literal_eval(str(message['data']))
            #print ret
            messageJson = serDatas(ret)

            if message['data'] != 1:
                     if Distance(locationLatitude, locationLongitude, json.loads(messageJson)['latitude'], json.loads(messageJson)['longitude']) < float(locationRadius): #if message is in filter area
                         print json.loads(messageJson)['contenu']

#################################################################################################

#r = redis.StrictRedis(host="172.30.1.135", port=6380, db=0)

#p = r.pubsub()
#p.subscribe('App_BD')

#while(1):
#    message = p.get_message()
#    if message:
#       ret = ast.literal_eval(str(message['data']))
#        #print ret
#        messageJson = serDatas(ret)
#
#        if message['data'] != 1:
#            print json.loads(messageJson)['contenu']
