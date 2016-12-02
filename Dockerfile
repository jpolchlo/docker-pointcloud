FROM openjdk:8

# ------------------------------------------------------------------ Basic Setup
RUN apt-get -y update
RUN apt-get -y install libgeos-dev libgeotiff-dev cmake g++ libgdal-dev
RUN mkdir /work 

# -------------------------------------------------------------- Spark (in case)
WORKDIR /work
RUN wget http://d3kbcqa49mib13.cloudfront.net/spark-2.0.1-bin-hadoop2.7.tgz && \
    tar xzf spark-2.0.1-bin-hadoop2.7.tgz
ENV PATH=$PATH:/work/spark-2.0.1-bin-hadoop2.7/bin

# ------------------------------------------------------------ PDAL dependencies
WORKDIR /work
RUN git clone https://github.com/verma/laz-perf.git laz-perf
WORKDIR /work/laz-perf
RUN cmake . && \
    make && \
    make install

WORKDIR /work
RUN git clone https://github.com/LASzip/LASzip.git laszip
WORKDIR /work/laszip
RUN git checkout e7065cbc5bdbbe0c6e50c9d93d1cd346e9be6778 && \
    cmake . && \
    make && \
    make install

# ------------------------------------------------------------ PDAL and PDAL JNI
WORKDIR /work
RUN git clone https://github.com/pomadchin/PDAL.git PDAL-git && \
    mkdir /work/PDAL-git/makefiles
WORKDIR /work/PDAL-git/makefiles
RUN cmake -DWITH_LAZPERF=ON -DWITH_GEOTIFF=ON -DWITH_LASZIP=ON -DWITH_APPS=ON -DCMAKE_BUILD_TYPE=Release -G "Unix Makefiles" ../ && \
    make -j8 && \
    make install
RUN git checkout feature/pdal-jni
WORKDIR /work/PDAL-git/java
RUN ./sbt native/nativeCompile && \
    cp native/target/native/x86_64-linux/bin/libpdaljni.1.4.so /usr/local/lib && \
    ./sbt "project core" publishLocal
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
ENV CMAKE_INCLUDE_PATH=$CMAKE_INCLUDE_PATH:/usr/local/include
RUN ./sbt tests/test

# ------------------------------------------------------------------- GeoTrellis
WORKDIR /work
RUN git clone https://github.com/locationtech/geotrellis.git
WORKDIR /work/geotrellis
RUN git fetch origin milestone/pointcloud:milestone/pointcloud && \
    git checkout milestone/pointcloud && \
    ./sbt "project pointcloud" compile
RUN ./scripts/publish-local.sh

WORKDIR /work