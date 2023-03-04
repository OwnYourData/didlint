FROM ruby:2.6.9-slim
MAINTAINER "Christoph Fabianek" christoph@ownyourdata.eu

RUN addgroup user && \
    adduser --ingroup user --disabled-password user && \
    apt-get update && \
    apt-get install -y make gcc musl-dev

RUN gem install json httparty && \
    gem update --system

COPY status.rb /status.rb

CMD ["/status.rb"]
