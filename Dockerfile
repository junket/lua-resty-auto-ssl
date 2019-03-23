FROM openresty/openresty:1.13.6.2-2-centos

# Build dependencies.
RUN yum -y install make

# Dependencies for the release process.
RUN yum -y install git zip

# JCH: More dependencies
RUN yum -y install openssl

RUN mkdir /app
WORKDIR /app

COPY Makefile /app/Makefile
RUN make install-test-deps-yum
RUN make install-test-deps
RUN luarocks install lua-resty-auto-ssl
# RUN mkdir /etc/resty-auto-ssl

COPY . /app

# Pass env vars from the local server to the image
ENV PORT 5000
ENV REDIS_URL redis://redis:6379
ENV FORWARD_TO_URL http://localhost:3000

# Generate a self-signed cert for Nginx to start with.
RUN openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
  -subj '/CN=sni-support-required-for-valid-ssl' \
  -keyout /etc/ssl/resty-auto-ssl-fallback.key \
  -out /etc/ssl/resty-auto-ssl-fallback.crt

# Copy nginx.conf and replace its vars with env vars:  Heroku's PORT and FORWARD_TO_URL.
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
RUN envsubst '\$PORT \$FORWARD_TO_URL' < /usr/local/openresty/nginx/conf/nginx.conf > /usr/local/openresty/nginx/conf/nginx.conf

# Break up REDIS_URL into components and replace them in nginx.conf.
# See: https://stackoverflow.com/questions/6174220/parse-url-in-shell-script
# Remove the scheme and extract components:
RUN url="`echo $REDIS_URL | sed s,'redis://',,g`" && \
  REDIS_AUTH="`echo $url | grep @ | cut -d @ -f1`" && \
  hostport="`echo $url | sed s,$auth@,,g | cut -d/ -f1`" && \
  REDIS_HOST="`echo $hostport | grep : | cut -d: -f1`" && \
  REDIS_PORT="`echo $hostport | grep : | cut -d: -f2`" && \
  sed -i -e 's/REDIS_AUTH/'"$REDIS_AUTH"'/g' /usr/local/openresty/nginx/conf/nginx.conf && \
  sed -i -e 's/REDIS_HOST/'"$REDIS_HOST"'/g' /usr/local/openresty/nginx/conf/nginx.conf && \
  sed -i -e 's/REDIS_PORT/'"$REDIS_PORT"'/g' /usr/local/openresty/nginx/conf/nginx.conf

# Diagnostics on local:
RUN cat /usr/local/openresty/nginx/conf/nginx.conf
RUN nginx -t
CMD bin/start_nginx
