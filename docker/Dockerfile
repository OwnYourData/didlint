# soya-js as used by soya-web-cli, for SHACL validation in offline mode (linux/amd64 and linux/arm64)
FROM oydeu/soya-web-cli:261028@sha256:419886a655afa47c1ed7682bae2d4d5c77c496af69479e4223fe1731bc0077f1 AS soya

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

COPY --from=soya /app/node_modules /opt/node_modules
RUN ln -s /opt/node_modules/soya-js /opt/soya-js
ENV SOYA_JS=/opt/soya-js

COPY . .

CMD ["./docker/init.sh"]

EXPOSE 3000
