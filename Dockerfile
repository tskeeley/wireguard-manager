FROM alpine:latest
LABEL maintainer="Prajwal Koirala <prajwalkoirala23@protonmail.com>"
RUN apk update && \
    apk add curl && \
    curl https://raw.githubusercontent.com/complexorganizations/wireguard-manager/main/wireguard-server.sh --create-dirs -o /usr/local/bin/wireguard-server.sh && \
    chmod +x /usr/local/bin/wireguard-server.sh
CMD ["bash /usr/local/bin/wireguard-server.sh"]
