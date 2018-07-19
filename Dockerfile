FROM alpine
	
RUN apk --update add \
    rsyslog \
    bash \
    openjdk7 \
    make \
    wget \
  && : adding gnuplot for graphing \
  && apk add gnuplot
	
ENV TSDB_VERSION 2.3.0
ENV HBASE_VERSION 1.2.4
ENV JAVA_HOME /usr/lib/jvm/java-1.7-openjdk
ENV PATH $PATH:/usr/lib/jvm/java-1.7-openjdk/bin/

RUN mkdir -p /opt/bin/
RUN mkdir /opt/opentsdb/
WORKDIR /opt/opentsdb/

RUN apk --update add --virtual builddeps \
    build-base \
    autoconf \
    automake \
    git \
    python \
  && : Install OpenTSDB and scripts \
  && wget --no-check-certificate \
    -O v${TSDB_VERSION}.zip \
    https://github.com/OpenTSDB/opentsdb/archive/v${TSDB_VERSION}.zip \
  && unzip v${TSDB_VERSION}.zip \
  && rm v${TSDB_VERSION}.zip \
  && cd /opt/opentsdb/opentsdb-${TSDB_VERSION} \
  && ./build.sh \
  && : because of issue https://github.com/OpenTSDB/opentsdb/issues/707 \
  && : commented lines do not work. These can be uncommeted when version of \
  && : tsdb is bumped. Entrypoint will have to be updated too. \
  && : cd build \
  && : make install \
  && : cd / \
  && : rm -rf /opt/opentsdb/opentsdb-${TSDB_VERSION} \
  && apk del builddeps \
  && rm -rf /var/cache/apk/*

#Install HBase and scripts
RUN mkdir -p /data/hbase /root/.profile.d /opt/downloads

WORKDIR /opt/downloads
RUN wget -O hbase-${HBASE_VERSION}.bin.tar.gz http://www-eu.apache.org/dist/hbase/stable/hbase-${HBASE_VERSION}-bin.tar.gz && \
    tar xzvf hbase-${HBASE_VERSION}.bin.tar.gz && \
    mv hbase-${HBASE_VERSION} /opt/hbase && \
    rm hbase-${HBASE_VERSION}.bin.tar.gz

ADD docker/hbase-site.xml /opt/hbase/conf/hbase-site.xml
ADD docker/start_opentsdb.sh /opt/bin/start_opentsdb.sh.bkp
ADD docker/create_tsdb_tables.sh /opt/bin/create_tsdb_tables.sh.bkp
ADD docker/start_hbase.sh /opt/bin/start_hbase.sh.bkp

WORKDIR /opt/bin/

#DOS2UNIX CONVERT
RUN tr -d '\r' < start_hbase.sh.bkp > start_hbase.sh
RUN tr -d '\r' < start_opentsdb.sh.bkp > start_opentsdb.sh
RUN tr -d '\r' < /opt/bin/create_tsdb_tables.sh.bkp > /opt/bin/create_tsdb_tables.sh

RUN for i in /opt/bin/start_hbase.sh /opt/bin/start_opentsdb.sh /opt/bin/create_tsdb_tables.sh; \
    do \
        sed -i "s#::JAVA_HOME::#$JAVA_HOME#g; s#::PATH::#$PATH#g; s#::TSDB_VERSION::#$TSDB_VERSION#g;" $i; \
    done

RUN chmod -R 775 /opt/bin/*

EXPOSE 60000 60010 60030 4242 16010

VOLUME ["/data/hbase", "/tmp"]
CMD bash -c "/opt/hbase/bin/start-hbase.sh && /opt/bin/start_opentsdb.sh;"
