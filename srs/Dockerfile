FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# 使用阿里云源
RUN sed -i 's@http://.*archive.ubuntu.com@http://mirrors.aliyun.com@g' /etc/apt/sources.list && \
    sed -i 's@http://.*security.ubuntu.com@http://mirrors.aliyun.com@g' /etc/apt/sources.list && \
    apt update && apt install -y ca-certificates && \
    sed -i 's@http://mirrors.aliyun.com@https://mirrors.aliyun.com@g' /etc/apt/sources.list && \
    apt update && apt install -y \
    build-essential libssl-dev git yasm pkg-config cmake curl

RUN git clone -b develop https://github.com/ossrs/srs.git /srs
WORKDIR /srs/trunk

RUN ./configure --gb28181 && make -j$(nproc)

EXPOSE 1935 1985 8080 8000 5060/udp 10000-20000/udp

CMD ["./objs/srs", "-c", "/srs.conf"]