FROM ubuntu:latest

RUN apt update -y && apt upgrade -y
RUN apt install rtl-433 -y
RUN mkdir /app

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]