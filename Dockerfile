FROM resin/rpi-supervisor:6659c1

RUN apt-get -q update && apt-get install -qy libasound2-dev ntpdate

ADD package.json /sonos/package.json
RUN cd /sonos && npm install --production

ADD start /start

ADD src /sonos/src
