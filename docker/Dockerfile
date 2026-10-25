FROM ruby:3.4.12-alpine3.24@sha256:53dd359160ceeb7963f8e9efea8a2bbbb65278276e024bb0f058261152b5610d
LABEL org.opencontainers.image.authors="Christoph Fabianek <christoph@ownyourdata.eu>"

RUN apk add --no-cache build-base git bash curl nodejs libsodium-dev openssl-dev yaml-dev
WORKDIR /usr/src/app
ENV RAILS_ROOT=/usr/src/app/
ENV BUNDLE_FROZEN=true
ENV BUNDLE_WITHOUT=development:test

COPY Gemfile Gemfile.lock $RAILS_ROOT
RUN gem install bundler -v 2.6.9 && \
	bundle install

COPY . .
RUN SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile

CMD ["./docker/init.sh"]

EXPOSE 3000
