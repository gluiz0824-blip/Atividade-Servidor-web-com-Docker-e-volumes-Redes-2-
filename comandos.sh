#!/usr/bin/env bash
# Executar pelo Bash a partir de qualquer diretório: bash comandos.sh
# Requer Docker e curl. Substitua PREENCHER_MATRICULA em quatro arquivos antes de iniciar.
# Para fazer tudo novamente do zero, use os comandos de limpeza ao fim deste arquivo.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p evidencias

for arquivo in Dockerfile nginx/default.conf site/index.html RELATORIO.md; do
  if grep -q 'PREENCHER_MATRICULA' "$arquivo"; then
    echo "Preencha sua matrícula em $arquivo antes de executar." >&2
    exit 1
  fi
done
command -v docker >/dev/null || { echo 'Docker não encontrado.' >&2; exit 1; }
command -v curl >/dev/null || { echo 'curl não encontrado.' >&2; exit 1; }

pausa() {
  if [ -t 0 ]; then
    printf '\n%s\n' "$1"
    read -r -p 'Faça o(s) print(s) solicitado(s) e pressione Enter para continuar... ' _
  fi
}

# Parte 1 — site com bind mount somente leitura
whoami
hostname
docker version
# Deixa o HTML na versão inicial para demonstrar a edição de forma repetível.
sed 's/versão 2/versão 1/g' site/index.html > site/index.tmp
mv site/index.tmp site/index.html

docker run -d --name web-bind -p 8080:80 \
  -v "$(pwd)/site:/usr/share/nginx/html:ro" \
  nginx:alpine
sleep 2
curl -isS http://localhost:8080/ | tee evidencias/parte1-03-curl-inicial.txt
curl -isS http://localhost:8080/sobre.html | tee evidencias/parte1-03-curl-sobre.txt
docker inspect web-bind --format '{{.Id}} {{.State.StartedAt}}' \
  | tee evidencias/parte1-00-identidade-container-antes.txt
pausa 'Parte 1: salve parte1-01-pagina-antes.png (localhost:8080, versão 1).'

# Editar no host, sem docker restart nem docker build.
sed 's/versão 1/versão 2/g' site/index.html > site/index.tmp
mv site/index.tmp site/index.html
curl -isS http://localhost:8080/ | tee evidencias/parte1-03-curl-depois.txt
docker inspect web-bind --format '{{.Id}} {{.State.StartedAt}}' \
  | tee evidencias/parte1-00-identidade-container-depois.txt
pausa 'Parte 1: salve parte1-02-pagina-depois.png (localhost:8080, versão 2).'

# Este comando DEVE falhar, porque o bind mount está com :ro.
if docker exec web-bind touch /usr/share/nginx/html/teste.txt \
    > evidencias/parte1-04-erro-ro.txt 2>&1; then
  cat evidencias/parte1-04-erro-ro.txt
  echo 'ERRO: o teste de somente leitura não falhou conforme esperado.' >&2
  exit 1
else
  cat evidencias/parte1-04-erro-ro.txt
fi
docker inspect web-bind --format '{{json .Mounts}}' \
  | tee evidencias/parte1-05-mounts.txt
whoami
hostname
pausa 'Parte 1: tire prints do curl, do erro de somente leitura e do inspect.'
docker rm -f web-bind

# Parte 2 — imagem própria e logs em volume nomeado
whoami
hostname
docker build -t meu-web:1.0 . 2>&1 | tee evidencias/parte2-01-build.txt
docker images meu-web | tee evidencias/parte2-02-images.txt
docker volume create logs-web | tee evidencias/parte2-00-volume-criado.txt
docker run -d --name web-vol -p 8081:80 \
  -v logs-web:/var/log/nginx \
  meu-web:1.0
sleep 2
# Cinco requisições incluindo página inicial, sobre, saúde e uma URL 404.
curl -isS http://localhost:8081/ | tee evidencias/parte2-03-curl-inicio.txt
curl -isS http://localhost:8081/sobre.html | tee evidencias/parte2-03-curl-sobre.txt
curl -isS http://localhost:8081/saude | tee evidencias/parte2-03-curl-saude.txt
curl -isS http://localhost:8081/pagina-inexistente | tee evidencias/parte2-03-curl-404.txt
curl -isS http://localhost:8081/saude | tee evidencias/parte2-03-curl-saude-2.txt
docker exec web-vol cat /var/log/nginx/acessos.log \
  | tee evidencias/parte2-04-acessos.txt
docker volume inspect logs-web | tee evidencias/parte2-05-volume-inspect.txt
pausa 'Parte 2: tire prints do build, images, /saude, log com 404 e inspect.'

# Parte 3 — persistência ao excluir e recriar contêineres
whoami
hostname
docker exec web-vol wc -l /var/log/nginx/acessos.log \
  | tee evidencias/parte3-01-linhas-antes.txt
docker rm -f web-vol
docker volume ls | tee evidencias/parte3-02-volume-apos-remocao.txt
pausa 'Parte 3: tire print das linhas iniciais e do volume existente após docker rm.'

docker run -d --name web-vol -p 8081:80 \
  -v logs-web:/var/log/nginx \
  meu-web:1.0
sleep 2
curl -isS http://localhost:8081/saude | tee evidencias/parte3-03-curl-recriado.txt
curl -isS http://localhost:8081/apos-recriacao | tee evidencias/parte3-03-curl-apos-recriacao.txt
docker exec web-vol wc -l /var/log/nginx/acessos.log \
  | tee evidencias/parte3-03-linhas-depois.txt
docker exec web-vol cat /var/log/nginx/acessos.log \
  | tee evidencias/parte3-03-log-persistente.txt
docker run --rm -v logs-web:/dados alpine tail -n 20 /dados/acessos.log \
  | tee evidencias/parte3-04-alpine-tail.txt
pausa 'Parte 3: tire prints do log antigo+novo e do tail pelo Alpine.'

docker run -d --name web-vol2 -p 8082:80 \
  -v logs-web:/var/log/nginx \
  meu-web:1.0
sleep 2
curl -isS http://localhost:8081/origem-8081 \
  | tee evidencias/parte3-06-curl-porta-8081.txt
curl -isS http://localhost:8082/origem-8082 \
  | tee evidencias/parte3-06-curl-porta-8082.txt
curl -isS http://localhost:8081/saude | tee evidencias/parte3-06-saude-8081.txt
curl -isS http://localhost:8082/saude | tee evidencias/parte3-06-saude-8082.txt
docker ps | tee evidencias/parte3-05-docker-ps.txt
docker exec web-vol cat /var/log/nginx/acessos.log \
  | tee evidencias/parte3-06-log-compartilhado.txt
# URLs específicas permitem identificar cada porta de origem no log compartilhado.
docker exec web-vol grep -E 'origem-8081|origem-8082' /var/log/nginx/acessos.log \
  | tee evidencias/parte3-06-prova-duas-portas.txt
pausa 'Parte 3: tire prints de docker ps e dos acessos das duas portas no log.'

docker run -d --name web-sem-vol -p 8083:80 meu-web:1.0
sleep 2
curl -isS http://localhost:8083/somente-sem-volume \
  | tee evidencias/parte3-07-curl-sem-volume.txt
docker exec web-sem-vol cat /var/log/nginx/acessos.log \
  | tee evidencias/parte3-07-log-antes-remocao.txt
docker rm -f web-sem-vol
docker exec web-vol sh -c \
  "grep -F '/somente-sem-volume' /var/log/nginx/acessos.log || echo 'Requisicao exclusiva do web-sem-vol ausente de logs-web'" \
  | tee evidencias/parte3-07-comparacao.txt
pausa 'Parte 3: tire print do teste com web-sem-vol e do contraste com logs-web.'

# Bônus — Docker Compose (após os prints obrigatórios; executar manualmente)
# docker rm -f web-vol web-vol2
# docker compose up -d
# docker compose ps
# curl -isS http://localhost:8081/saude
# curl -isS http://localhost:8082/saude
# docker compose down

# Limpeza para refazer TUDO do zero (executar manualmente; APAGA logs-web):
# docker rm -f web-bind web-vol web-vol2 web-sem-vol
# docker volume rm logs-web
