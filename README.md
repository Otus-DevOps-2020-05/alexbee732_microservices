# alexbee732_microservices
alexbee732 microservices repository

# ДЗ №13 Docker-2
Установлен docker, docker-compose, docker-machine
Поигрались с командами докера
Сделали коммит работающего тонтейнера
Сделали docker host в yc, используя docker-machine
Собрали образ reddit-app, используя Dockerfile
Проверили работу приложения на docker-host
Залили образ на docker hub
Запустили контейнер локально с образом с docker hub

TODO: Выполнить второе задание со *

# ДЗ №14 Docker-3

Создали на yc инстанс для docker-host:
yc compute instance create \
--name docker-host \
--zone ru-central1-a \
--network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
--create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=15 \
--ssh-key ~/.ssh/appuser.pub

Настроили там docker-host:
docker-machine create \
--driver generic \
--generic-ip-address=84.201.173.59 \
--generic-ssh-user yc-user \
--generic-ssh-key ~/.ssh/appuser \
docker-host

Подключились к docker-host в yc:
docker-machine ls
eval $(docker-machine env docker-host)

Скачали последний образ монги + собрали и образа для компонентов приложения использую Docker файл
docker pull mongo:latest
docker build -t yc-user/post:1.0 ./post-py
docker build -t yc-user/comment:1.0 ./comment
docker build -t yc-user/ui:1.0 ./ui

Создали сеть reddit и запустили контейнеры, прописав алиасы и порты:
docker network create reddit
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest
docker run -d --network=reddit --network-alias=post yc-user/post:1.0
docker run -d --network=reddit --network-alias=comment yc-user/comment:1.0
docker run -d --network=reddit -p 9292:9292 yc-user/ui:1.0
docker kill $(docker ps -q)

Оптимизировали Dockerfile для ui и создали volume для монги, чтобы коментарии не удалялись при перезапуске контейнеров:
docker volume create reddit_db
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db -v reddit_db:/data/db mongo:latest
docker run -d --network=reddit --network-alias=post yc-user/post:1.0
docker run -d --network=reddit --network-alias=comment yc-user/comment:1.0
docker run -d --network=reddit -p 9292:9292 yc-user/ui:2.0

Почистили инстанс в yc:
yc compute instances delete docker-host
