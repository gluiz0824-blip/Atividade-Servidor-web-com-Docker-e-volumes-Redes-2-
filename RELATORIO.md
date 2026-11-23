# Relatorio - Servidor web com Docker e volumes

Nome: Luiz Guilherme Prado Morais  
Matricula: 20242003300398  
Turma: CIC1001 A03 - Redes de Computadores 2

## 1. Bind mount e volume nomeado
O bind mount ligou a pasta site do meu computador ao diretorio servido pelo Nginx.
A pagina passou da versao 1 para a versao 2 depois da edicao no host, sem reiniciar o container.
O volume nomeado logs-web foi criado e gerenciado pelo Docker, persistindo os logs separadamente.
Usaria bind mount para editar arquivos no desenvolvimento e volume nomeado para persistir dados da aplicacao.

## 2. Somente leitura
O sufixo :ro montou o site em modo somente leitura dentro do container.
Ao tentar criar teste.txt pelo docker exec, o comando falhou com "Read-only file system", como mostra o print da Parte 1.
O docker inspect tambem mostrou a montagem com RW false.
Assim, o Nginx pode ler os arquivos do site, mas o container nao pode escrever nessa pasta montada.

## 3. Logs com e sem volume
O log do web-sem-vol continha o acesso /somente-sem-volume antes da remocao.
Depois de remover e recriar esse container sem volume, o arquivo de log estava vazio antes de novos acessos.
Isso ocorreu porque o log estava na camada gravavel do container removido.
Com logs-web, preservei as 7 linhas antigas e obtive 10 linhas apos recriar o web-vol e acessar novamente.

## 4. Local e remocao do volume
O docker volume inspect retornou o Mountpoint /var/lib/docker/volumes/logs-web/_data.
No Docker Desktop com containers Linux, esse caminho pertence ao ambiente Linux gerenciado pelo Docker.
O docker rm -f web-vol removeu o container, mas logs-web continuou listado e preservou o arquivo.
Para apagar efetivamente o volume, seria necessario liberar seus containers e executar docker volume rm logs-web.

## 5. Atualizacao do site
Na Parte 1, a edicao do HTML apareceu sem rebuild, pois o arquivo era lido diretamente da pasta montada.
Na Parte 2, os arquivos foram copiados para dentro da imagem pelo Dockerfile.
Para publicar alteracoes, preciso reconstruir a imagem com docker build e recriar os containers com a nova imagem.
Prefiro bind mount no desenvolvimento e imagem propria para distribuir uma versao definida em producao.

## 6. Portas dos containers
web-vol e web-vol2 usam a porta interna 80 em ambientes de rede separados.
O mapeamento 8081:80 encaminha a porta 8081 do computador para o primeiro container.
O mapeamento 8082:80 encaminha a porta 8082 para o segundo, sem disputar a mesma porta do host.
A rede bridge e os namespaces de rede permitem essa separacao; os acessos marcados das duas portas apareceram no mesmo log.

## Bonus - Docker Compose
O compose.yaml declara web-vol e web-vol2, as portas 8081 e 8082 e o volume compartilhado logs-web.
Executei docker compose up -d e confirmei os dois servicos e as respostas de /saude com minha matricula.
Depois executei docker compose down e confirmei que o volume continuou listado.
Para repetir, use docker compose up -d; para parar, docker compose down, sem a opcao -v.