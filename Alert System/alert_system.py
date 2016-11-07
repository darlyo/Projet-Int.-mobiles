import redis

r = redis.StrictRedis(host='localhost', port=6379, db=0)
r.get('foo')

#pool = redis.ConnectionPool(host='localhost', port=6379, db=0)
#r = redis.Redis(connection_pool=pool)

p = r.pubsub()

p.subscribe('test')

#look if its subscribed
message = p.get_message()

#unsuscribe all
#p.unsubscribe()

ddd


