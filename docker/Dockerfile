FROM oydeu/soya-cli:alpha
MAINTAINER "Christoph Fabianek" christoph@ownyourdata.eu

USER root
RUN mkdir -p /usr/src/app && \
	apk add --no-cache libsodium-dev build-base git make gcc musl-dev jq npm openjdk8 bash curl libpq-dev sqlite-dev
WORKDIR /usr/src/app

COPY Gemfile $WORKDIR
RUN git config --global url."https://".insteadOf git:// && \
	bundle install && \
	bundle update

COPY . .
RUN bundle install

CMD ["./docker/init.sh"]

EXPOSE 3000 3000
