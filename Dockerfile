FROM debian:latest
LABEL maintainer="Prajwal Koirala <prajwalkoirala23@protonmail.com>"
EXPOSE 51820
EXPOSE 53
RUN apt-get update && \
    apt-get install curl -y && \
    curl https://raw.githubusercontent.com/complexorganizations/wireguard-manager/main/wireguard-server.sh --create-dirs -o /usr/local/bin/wireguard-server.sh && \
    chmod +x /usr/local/bin/wireguard-server.sh
