FROM ubuntu:16.04

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME
COPY . $APP_HOME

RUN apt-get update \
    && apt-get install -y ruby-full ruby-dev build-essential \
    && gem install bundler --no-ri --no-rdoc \
    && bundle install \
    && apt-get purge -y ruby-dev build-essential ruby-full \
    && apt-get install -y ruby \
    && apt-get clean && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

CMD ["puma"]
