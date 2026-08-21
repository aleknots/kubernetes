FROM nginx:1.27-alpine
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
RUN apk add --no-cache gettext
COPY index.html.tmpl /usr/share/nginx/html/index.html.tmpl
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
  && rm -f /usr/share/nginx/html/index.html
EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
