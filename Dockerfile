FROM nginx:alpine
LABEL autor="Luiz Guilherme Prado Morais - 20242003300398"
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY site/ /usr/share/nginx/html/
EXPOSE 80
