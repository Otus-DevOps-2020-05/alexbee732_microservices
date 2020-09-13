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
--generic-ip-address=84.201.157.238 \
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

# ДЗ №15 Docker-4

Создали контейнер с none сетью и запустили ifconfig:
docker run -ti --rm --network none joffotron/docker-net-tools -c ifconfig

Создали контейнер с host сетью и запустили ifconfig:
docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig

Попробовали запустить несколько контейнеров с nginx с сетью host:
docker run --network host -d nginx
В итоге все контейнеры кроме первого сами останавливались (видимо из-за того, что порт уже был занят первым контейнером, а он общий в сети host)

Запустили проект reddit с использованием bringe сети:
docker network create reddit --driver bridge
docker run -d --network=reddit mongo:latest
docker run -d --network=reddit yc-user/post:1.0
docker run -d --network=reddit yc-user/comment:1.0
docker run -d --network=reddit -p 9292:9292 yc-user/ui:1.0
(так не вышло из-за отсутствия алиасов)

После добавления алиасов, используемых в Docker файлах, все начинает работать:
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest
docker run -d --network=reddit --network-alias=post yc-user/post:1.0
docker run -d --network=reddit --network-alias=comment  yc-user/comment:1.0
docker run -d --network=reddit -p 9292:9292 yc-user/ui:1.0

Запускаем проект на двух bridge сетях:
docker network create back_net --subnet=10.0.2.0/24
docker network create front_net --subnet=10.0.1.0/24

docker run -d --network=front_net -p 9292:9292 --name ui  yc-user/ui:1.0
docker run -d --network=back_net --name comment  yc-user/comment:1.0
docker run -d --network=back_net --name post  yc-user/post:1.0
docker run -d --network=back_net --name mongo_db --network-alias=post_db --network-alias=comment_db mongo:latest

Подключаем контейнеры ко второй сети:
docker network connect front_net post
docker network connect front_net comment

Зайти на docker-machine по ssh:
docker-machine ssh docker-host

Установили docker-compose, создали файл docker-compose.yml с описанием сервисов, томов и сетей
Изменили docker-compose.yml для работы приложения в двух bringe сетях
docker-compose up -d
docker-compose ps

Параметризовали версию монги и порт ui и добавили переменные в .env файл

Узнайте как образуется базовое имя проекта. Можно ли его задать? Если можно то как?
src_comment_1, src_post_1, src_post_db_1, src_ui_1
Очевидно, дефолтное название получается из названия директории. Переопределяется флагом -p или через переменную окружения COMPOSE_PROJECT_NAME.

# ДЗ №17 monitoring-1

Подняли машинку в yc и развернули на ней docker:
yc compute instance create \
 --name docker-host \
 --zone ru-central1-a \
 --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
 --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=15 \
 --ssh-key ~/.ssh/appuser.pub
 
docker-machine create \
 --driver generic \
 --generic-ip-address=130.193.49.73 \
 --generic-ssh-user yc-user \
 --generic-ssh-key ~/.ssh/appuser \
 docker-host
 
eval $(docker-machine env docker-host)
 
Запустили контейнер с образов prometeus:
docker run --rm -p 9090:9090 -d --name prometheus prom/prometheus

Создали Docker файл для поднятия prometheus и файл Prometheus.yml с настройками, запустили:
export USER_NAME=alexbee732
docker build -t $USER_NAME/prometheus .

Собрали образы микросервисов:
for i in ui post-py comment; do cd src/$i; bash docker_build.sh; cd -; done

Добавили сервис prometheus в docker-compose.yml и запустили контейнеры:
docker-compose up -d

Попробовали выключать и включать контейнер post для проверки мониторинга ui_health:
docker-compose stop post
docker-compose start post

Добавили сервис node-exporter в docker-compose.yml для мониторинга работы докер хоста + добавили новый сервис для отследивания в prometheus.yml, пересобрали образы и перезапустили:
docker build -t $USER_NAME/prometheus .
docker-compose down
docker-compose up -d

Посмотрели график node_load1 с загрузкой cpu, прогрузили инстанс и посмотрели, как график меняется:
docker-machine ssh docker-host
yes > /dev/null

Запушили образы на докер хаб:
docker login
for i in ui post-py comment prometheus; do docker push $USER_NAME/$i; cd -; done

Задание со *:
Добавили в docker-compose.yml сервис blackbox-exporter
Добавили blackbox в конфиг Prometheus.yml (проверку http://130.193.49.73:9292/, т.е. ui приложеньки)
Пересобрали образ и перезапустили:
docker-compose down
docker build -t $USER_NAME/prometheus .
docker-compose up -d
Посмотрели на график probe_success, при этом останавливали и запускали контейнер ui, чтобы проверить работу, все супер:
docker-compose stop ui
docker-compose start ui

Удалили виртуалку:
docker-machine rm docker-host
yc compute instance delete docker-host

