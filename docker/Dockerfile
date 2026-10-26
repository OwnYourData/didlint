# soya-js as used by soya-web-cli, for SHACL validation in offline mode
FROM oydeu/soya-web-cli:260704b@sha256:1634af3d6aff73960d3238fcb3f105743580d632ac08f6d27d9e7e0c21d6a01b AS soya

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

COPY --from=soya /lib2 /opt/soya-js
ENV SOYA_JS=/opt/soya-js

COPY . .
RUN SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile

CMD ["./docker/init.sh"]

EXPOSE 3000
