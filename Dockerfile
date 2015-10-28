FROM java:8
MAINTAINER Jieke Choo <jiekechoo@sectong.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get install --no-install-recommends -y supervisor curl

RUN echo "Asia/Shanghai" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata

# Elasticsearch
RUN \
    apt-key adv --keyserver pool.sks-keyservers.net --recv-keys 46095ACC8548582C1A2699A9D27D666CD88E42B4 && \
    if ! grep "elasticsearch" /etc/apt/sources.list; then echo "deb http://packages.elastic.co/elasticsearch/1.7/debian stable main" >> /etc/apt/sources.list;fi && \
    if ! grep "logstash" /etc/apt/sources.list; then echo "deb http://packages.elastic.co/logstash/1.5/debian stable main" >> /etc/apt/sources.list;fi && \
    apt-get update

RUN \
    apt-get install --no-install-recommends -y elasticsearch && \
    apt-get clean && \
    sed -i '/#cluster.name:.*/a cluster.name: logstash' /etc/elasticsearch/elasticsearch.yml && \
    sed -i '/#path.data: \/path\/to\/data/a path.data: /data' /etc/elasticsearch/elasticsearch.yml

ADD etc/supervisor/conf.d/elasticsearch.conf /etc/supervisor/conf.d/elasticsearch.conf

# auto delete old indices daily
ADD scripts/elasticsearch-remove-old-indices.sh /usr/bin/elasticsearch-remove-old-indices.sh
RUN ln -s /usr/bin/elasticsearch-remove-old-indices.sh /etc/cron.daily/elasticsearch-remove-old-indices.sh

# Logstash
RUN apt-get install --no-install-recommends -y logstash && \
    apt-get clean

ADD etc/supervisor/conf.d/logstash.conf /etc/supervisor/conf.d/logstash.conf

# Logstash plugins
COPY output-jdbc/logstash-output-jdbc-0.1.1.gem /tmp/
RUN /opt/logstash/bin/plugin install /tmp/logstash-output-jdbc-0.1.1.gem
RUN mkdir -p /opt/logstash/vendor/jar/jdbc/
COPY output-jdbc/mysql-connector-java-5.1.36-bin.jar /opt/logstash/vendor/jar/jdbc/

# Kibana
RUN \
    curl -s http://192.168.1.10/downloads/kibana-4.1.2-linux-x64.tar.gz | tar -C /opt -xz && \
    ln -s /opt/kibana-4.1.2-linux-x64 /opt/kibana && \
    sed -i 's/port: 5601/port: 80/' /opt/kibana/config/kibana.yml

ADD etc/supervisor/conf.d/kibana.conf /etc/supervisor/conf.d/kibana.conf

RUN curl -s http://apache.fayea.com/incubator/zeppelin/0.5.0-incubating/zeppelin-0.5.0-incubating-bin-spark-1.4.0_hadoop-2.3.tgz | tar -C /opt -zx && ln -s /opt/zeppelin-0.5.0-incubating-bin-spark-1.4.0_hadoop-2.3/zeppelin-0.5.0-incubating /opt/zeppelin

RUN curl -s http://192.168.1.10/downloads/zeppelin-interpreter-mysql-0.5.0.tar.gz |tar -C /opt/zeppelin/interpreter -zx

ADD etc/zeppelin.conf /etc/supervisor/conf.d/zeppelin.conf

COPY zeppelin/zeppelin-site.xml /opt/zeppelin/conf/zeppelin-site.xml

COPY zeppelin/interpreter.json /opt/zeppelin/conf/interpreter.json

EXPOSE 8080

EXPOSE 8081

EXPOSE 80

ENV PATH /opt/logstash/bin:$PATH

CMD [ "/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf" ]

