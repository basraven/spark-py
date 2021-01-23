#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
ARG java_image_tag=8-jre-slim
# ARG spark_uid=185
FROM openjdk:${java_image_tag} AS base_img

# Added by Seb 1
ENV SPARK_VERSION 3.0.1
ENV HADOOP_VERSION 3.2
RUN apt-get update && \
    apt install wget -y && \
    wget https://mirror.serverion.com/apache/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION.tgz && \
    tar -zxvf spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION.tgz -C / && \
    mv /spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION /spark
WORKDIR /spark
# End Added by Seb

# # Before building the docker image, first build and make a Spark distribution following
# # the instructions in http://spark.apache.org/docs/latest/building-spark.html.
# # If this docker file is being used in the context of building your images from a Spark
# # distribution, the docker build command should be invoked from the top level directory
# # of the Spark distribution. E.g.:
# # docker build -t spark:latest -f kubernetes/dockerfiles/spark/Dockerfile .

RUN set -ex && \
    sed -i 's/http:\/\/deb.\(.*\)/https:\/\/deb.\1/g' /etc/apt/sources.list && \
    apt-get update && \
    ln -s /lib /lib64 && \
    apt install -y bash tini libc6 libpam-modules krb5-user libnss3 && \
    mkdir -p /opt/spark && \
    mkdir -p /opt/spark/examples && \
    mkdir -p /opt/spark/work-dir && \
    touch /opt/spark/RELEASE && \
    rm /bin/sh && \
    ln -sv /bin/bash /bin/sh && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd && \
    rm -rf /var/cache/apt/*

# COPY jars /opt/spark/jars
# COPY bin /opt/spark/bin
# COPY sbin /opt/spark/sbin
# COPY kubernetes/dockerfiles/spark/entrypoint.sh /opt/
# COPY examples /opt/spark/examples
# COPY kubernetes/tests /opt/spark/tests
# COPY data /opt/spark/data

# Added by Seb 2
RUN cp -R jars /opt/spark/jars && \
    cp -R bin /opt/spark/bin && \
    cp -R sbin /opt/spark/sbin && \
    cp -R kubernetes/dockerfiles/spark/entrypoint.sh /opt/ && \
    cp -R examples /opt/spark/examples && \
    cp -R kubernetes/tests /opt/spark/tests && \
    cp -R data /opt/spark/data
# END Added by Seb 2
ENV SPARK_HOME /opt/spark

WORKDIR /opt/spark/work-dir
RUN chmod g+w /opt/spark/work-dir

ENTRYPOINT [ "/opt/entrypoint.sh" ]

# # Specify the User that the actual main process will run as
# USER ${spark_uid}

# //////////////////////////// spark-py image after this

FROM base_img as spark-py
WORKDIR /

# Reset to root to run installation tasks
# USER 0

RUN mkdir ${SPARK_HOME}/python
# TODO: Investigate running both pip and pip3 via virtualenvs
RUN apt-get update && \
    apt install -y python python-pip && \
    apt install -y python3 python3-pip && \
    # We remove ensurepip since it adds no functionality since pip is
    # installed on the image and it just takes up 1.6MB on the image
    rm -r /usr/lib/python*/ensurepip && \
    pip install --upgrade pip setuptools && \
    # You may install with python3 packages by using pip3.6
    # Removed the .cache to save space
    rm -r /root/.cache && rm -rf /var/cache/apt/*

# COPY python/pyspark ${SPARK_HOME}/python/pyspark
# COPY python/lib ${SPARK_HOME}/python/lib

RUN cp -R /spark/python/pyspark /opt/spark/jars && \
    cp -R /spark/python/lib ${SPARK_HOME}/python/lib 


WORKDIR /opt/spark/work-dir
ENTRYPOINT [ "/opt/entrypoint.sh" ]

# # Specify the User that the actual main process will run as
# ARG spark_uid=185
# USER ${spark_uid}
