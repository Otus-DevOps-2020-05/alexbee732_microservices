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

# ДЗ №18 logging-1
Обновили код микросервисов для поддержки логирования

Пересобрали образы с новым кодом и запушили на докер хаб:
export USER_NAME='alexbee732'
cd ./src/ui && bash docker_build.sh && docker push $USER_NAME/ui
cd ../post-py && bash docker_build.sh && docker push $USER_NAME/post
cd ../comment && bash docker_build.sh && docker push $USER_NAME/comment

Подняли машинку в yc и развернули на ней docker:
yc compute instance create \
 --name docker-host \
 --zone ru-central1-a \
 --memory 4 \
 --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
 --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=15 \
 --ssh-key ~/.ssh/appuser.pub
 
docker-machine create \
 --driver generic \
 --generic-ip-address=178.154.224.89 \
 --generic-ssh-user yc-user \
 --generic-ssh-key ~/.ssh/appuser \
 logging
 
eval $(docker-machine env logging)

Создали docker-compose-logging.yml для сборки EFK стэка (elasticsearch, fluentd, kibana)

Создали Docker файл для сборки образа fluentd с прокидыванием конфигурационного файла
Собрали образ fluentd:
cd logging/fluentd
docker build -t $USER_NAME/fluentd .

Заменили теги в docker-compose.yml на :logging

Запустили сервисы приложения и посмотрели логи post сервиса:
cd docker && docker-compose up -d
docker-compose logs -f post

Заменили стандартный драйвер логов на fluentd для сервиса post в docker-compose.yml

Поднимаем инфру логирования и перезапускаем сервисы:
docker-compose -f docker-compose-logging.yml up -d
docker-compose down
docker-compose up -d

Изучаем логи в кибане, понимаем, что удобно распарсить поле log для удобства поиска, для этого добавляем настройки в fluent.conf:
<filter service.post>
  @type parser
  format json
  key_name log
</filter>
Пересобираем fluentd и перезапускаем сервисы логирования:
docker build -t $USER_NAME/fluentd .
docker-compose -f docker-compose-logging.yml up -d fluentd

В docker-compose.yml добавляем отправку логов во fluentd из сервиса ui и перезапускаем ui:
docker-compose stop ui
docker-compose rm ui
docker-compose up -d

В кибане нашли логи сервиса поиском по container_name : *ui* - видно, что логи не структурированы

Для парсинга таких логов используем регулярки в настройках в fluent.conf:
<filter service.ui>
  @type parser
  format /\[(?<time>[^\]]*)\]  (?<level>\S+) (?<user>\S+)[\W]*service=(?<service>\S+)[\W]*event=(?<event>\S+)[\W]*(?:path=(?<path>\S+)[\W]*)?request_id=(?<request_id>\S+)[\W]*(?:remote_addr=(?<remote_addr>\S+)[\W]*)?(?:method= (?<method>\S+)[\W]*)?(?:response_status=(?<response_status>\S+)[\W]*)?(?:message='(?<message>[^\']*)[\W]*)?/
  key_name log
</filter>
Пересобрали и перезапустили образ:
docker build -t $USER_NAME/fluentd .
docker-compose -f docker-compose-logging.yml up -d fluentd

Заменили регулярки на grok шаблоны в fluent.conf и пересобрали образ

Добавили Zipkin в compose-файл сервисов логирования
Добавили во все сервисы:
environment:
  - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
Перезапустили сервисы:
docker-compose up -d

Добавили сети из сервисов в инфра-сервис Zipkin и переподняли сервисы логирования:
docker-compose -f docker-compose-logging.yml -f docker-compose.yml down
docker-compose -f docker-compose-logging.yml -f docker-compose.yml up -d

Походили по страничке reddit и посмотрели трейсы

* Анализ багнутой версии в Zipkin показал, что в post имеется задержка около 3х секунд в сравнении с хорошей версией.
Порывшись в коде обнаружил time.sleep(3) в post_app.py в строке 167 :)

# ДЗ №19 kubernetes-1

Написал скрипт start.sh для разворачивания kubernetes в яндекс облаке в один клик
За основу взят гайд YC Kubernetes the Hard Way: https://gitlab.com/AlPervakov/yc-kubernetes-the-hart-way/-/tree/master/docs
Инфра в yc полностью разворачивается используя terraform
Мастер и воркер ноды провижинятся с использованием ansible (копирование + запуск скриптиков на хостах)
Облако сворачивается скриптом destroy.sh
Скринкаст процесса разворачивания: https://yadi.sk/i/h39E_kw8q3fAMg

# ДЗ №20 kubernetes-2

Установили Minikube
https://kubernetes.io/docs/tasks/tools/install-minikube/

Запустили кубер локально в virtualbox:
minikube start --driver=virtualbox

Посмотрели текущий контекст и список контекстов:
kubeclt config current-context
kubectl config get-contexts

Запустили приложение ui:
kubectl apply -f ui-deployment.yml

Убедились, что все работает:
kubectl get deployment

Пробросили порты через kubectl, чтобы проверить на localhost:8080:
kubectl get pods --selector component=ui
kubectl port-forward ui-644cd574bf-9hcq9 8080:9292

Создали сервисы для comment, post и mongodb для доступов по имени и порту из любых подов в нэймспейсе
Настроили сервисы для обращения к базе данных из post и comment

Создали сервис ui-service.yml для доступа к ui снаружи (type: NodePort)
Тип NodePort - на каждой ноде кластера открывает порт из диапазона 30000-32767 и переправляет
трафик с этого порта на тот, который указан в targetPort Pod (похоже на стандартный expose в docker)

minikube service ui
minikube service list

Список аддонов minikube:
minikube addons list

Открыли и посмотрели дашборд:
minikube addons enable dashboard
minikube dashboard

Создали namespace dev и запустили приложение в нем:
ubectl apply -f dev-namespace.yml
kubectl delete -f .
kubectl apply -n dev -f .
minikube service ui -n dev

Развернули Managed Service for Kubernetes в яндекс облаке
Подключились к кластеру в облаке:
yc managed-kubernetes cluster get-credentials haska8s --external

Деплоим приложение:
kubectl apply -f ./kubernetes/reddit/dev-namespace.yml
kubectl apply -f ./kubernetes/reddit/ -n dev
kubectl get nodes -o wide
kubectl describe service ui -n dev | grep NodePort

# ДЗ №21 kubernetes-3

Создали ui-ingress.yml с описанием ingress сервиса
Применили все манифесты:
kubectl apply -n dev -f .

Ingress не взлетел, т.к. ingress контроллера в yc у нас не было
Установили ingress контроллер, используя helm:

curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

https://kubernetes.github.io/ingress-nginx/deploy/#using-helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install my-release ingress-nginx/ingress-nginx

Посмотрели информацию об ingress:
kubectl get ingress -n dev

NAME   CLASS    HOSTS   ADDRESS         PORTS   AGE
ui     <none>   *       84.201.128.21   80      27m

Приложение стало доступно снаружи по адресу 84.201.128.21
Настроили подключение tls

Настроили хранилище для монги, используя PersistentVolume, PersistentVolumeClaim и StorageClass, настроили динамическое PVC
Теперь при удалении и пересоздании деплоймента с монгой данные сохраняются

# ДЗ №21 kubernetes-4

Установили приложение для работы с кубером helm (tiller ставить не понадобилось т.к. он deprecated)
Попробовали деплоить чарты с помощью helm

Установили gitlab (пришлось сильно отступить от домашки и установить последнюю версию + настроить на свой домен с tls)
Подключили кластер кубера в gitlab

Создали в гитлабе проекты для кажждого компонента
Настроили ci/cd в гитлабе для автоматизации сборки, тестирования и деплоя
