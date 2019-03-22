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

# RUN nginx_conf=/usr/local/openresty/nginx/conf/nginx.conf
# RUN nginx_conf="/etc/nginx/conf.d/default.conf"

# Copy nginx.conf and replace its vars with env vars:  Heroku's PORT, REDIS_URL, FORWARD_TO_URL.
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
RUN sed -i -e 's/ENV_PORT/'"$PORT"'/g' /usr/local/openresty/nginx/conf/nginx.conf

# Break up REDIS_URL into components and replace them in nginx.conf.
# See: https://stackoverflow.com/questions/6174220/parse-url-in-shell-script
# Remove the scheme and extract components:
RUN url="`echo $REDIS_URL | sed s,'redis://',,g`" && \
  auth="`echo $url | grep @ | cut -d @ -f1`" && \
  hostport="`echo $url | sed s,$auth@,,g | cut -d/ -f1`" && \
  host="`echo $hostport | grep : | cut -d: -f1`" && \
  port="`echo $hostport | grep : | cut -d: -f2`"

RUN sed -i -e 's/REDIS_AUTH/'"$auth"'/g' /usr/local/openresty/nginx/conf/nginx.conf
RUN sed -i -e 's/REDIS_HOST/'"$host"'/g' /usr/local/openresty/nginx/conf/nginx.conf
RUN sed -i -e 's/REDIS_PORT/'"$port"'/g' /usr/local/openresty/nginx/conf/nginx.conf

RUN sed -i -e 's/FORWARD_TO_URL/'"$FORWARD_TO_URL"'/g' /usr/local/openresty/nginx/conf/nginx.conf

RUN cat /usr/local/openresty/nginx/conf/nginx.conf
