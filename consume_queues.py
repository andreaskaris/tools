#!/bin/python
'''
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

This script draws heavily on https://gist.github.com/vagelim/64b355b65378ecba15b0

### How to use ###
./consume.py <queue name> <message number>

### Example ###
List queues of interest:
~
[root@overcloud-controller-0 ~]# rabbitmqctl list_queues name consumers messages | grep notifications
notifications.info	1	0
notifications.warn	1	0
notifications.audit	1	0
versioned_notifications.info	0	0
versioned_notifications.error	0	2
notifications.sample	1	0
notifications.critical	1	0
notifications.error	1	0
notifications.debug	1	0
~

Check queue contents:
~
export AMQP_USER=$(crudini --get /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid)
export AMQP_PASSWORD=$(crudini --get /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password)
export AMQP_HOST=$(ss -lntp | awk '/15672/ {print $4}' | awk -F ':' '{print $1}')
./consume.py versioned_notifications.error 100
'''

import sys
import json
import os
from kombu import Queue, Connection

consume_message = False
stats = {}
AMQP_USER = os.environ['AMQP_USER']
AMQP_PASSWORD = os.environ['AMQP_PASSWORD']
AMQP_HOST = os.environ['AMQP_HOST']
queue_name = sys.argv[1]
max_messages = int(sys.argv[2])

def callback(body, message):
    oslo_message = json.loads(body['oslo.message'])
    event_type = oslo_message['event_type']
    try:
        stats[event_type] = stats[event_type] + 1
    except:
        stats[event_type] = 1

    print '\n===== event_type: %s =====\n' % event_type
    print(json.dumps(message.delivery_info, indent = 4))
    print(json.dumps(oslo_message, indent=4))

    if consume_message:
      message.ack()

with Connection('amqp://{0}:{1}@{2}//'.format(AMQP_USER, AMQP_PASSWORD, AMQP_HOST)) as conn:
    with conn.Consumer(
                  Queue(queue_name, durable=False), 
                  callbacks=[callback]):
        try:
            for x in range(0, max_messages):
                conn.drain_events()
        except KeyboardInterrupt:
            exit()

print ''
print '======'
print ''
print 'Summary (event_type : count):'
print(json.dumps(stats, indent=4))
