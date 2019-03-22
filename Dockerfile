FROM openresty/openresty:1.13.6.2-2-centos

# Build dependencies.
RUN yum -y install make

# Dependencies for the release process.
RUN yum -y install git zip

RUN mkdir /app
WORKDIR /app

COPY Makefile /app/Makefile
RUN make install-test-deps-yum
RUN make install-test-deps

COPY . /app

# Generate a self-signed cert for Nginx to start with.
RUN openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
  -subj '/CN=sni-support-required-for-valid-ssl' \
  -keyout /etc/ssl/resty-auto-ssl-fallback.key \
  -out /etc/ssl/resty-auto-ssl-fallback.crt

# Copy nginx.conf and replace its vars with env vars:  Heroku's PORT, REDIS_URL, FORWARD_TO_URL.
COPY nginx.conf /etc/nginx/conf.d/default.conf
RUN sed -i -e 's/PORT/'"$PORT"'/g' /etc/nginx/conf.d/default.conf

# Break up REDIS_URL into components and replace them in nginx.conf.
# See: https://stackoverflow.com/questions/6174220/parse-url-in-shell-script
# Extract and remove the protocol
RUN proto="`echo $REDIS_URL | grep '://' | sed 's,^\(.*://\).*,\1,g'`"
RUN url=`echo $REDIS_URL | sed 's,'"$proto"',,g'`

# Extract the user and password.
RUN auth="`echo $url | grep @ | cut -d @ -f1`"

# Extract the host and port.
RUN hostport=`echo $url | sed 's,'"$auth@"',,g' | cut -d/ -f1`
RUN host=`echo $hostport | grep : | cut -d: -f1`
RUN port=`echo $hostport | grep : | cut -d: -f2`

RUN sed -i -e 's/REDIS_AUTH/'"$auth"'/g' /etc/nginx/conf.d/default.conf
RUN sed -i -e 's/REDIS_HOST/'"$host"'/g' /etc/nginx/conf.d/default.conf
RUN sed -i -e 's/REDIS_PORT/'"$port"'/g' /etc/nginx/conf.d/default.conf

RUN sed -i -e 's/FORWARD_TO_URL/'"$FORWARD_TO_URL"'/g' /etc/nginx/conf.d/default.conf