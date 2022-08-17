FROM ubuntu:jammy

ENV LANG=C.UTF-8

# create interchange user
## need to set the uid and gid to match the ownership of the bind mount folder
ARG host_uid
ARG host_gid
RUN groupadd -g $host_gid interchange
RUN useradd -m -u $host_uid -g $host_gid interchange

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get -q -y install build-essential curl libssl-dev unzip postgresql-server-dev-all libmysqlclient-dev
RUN curl -L https://cpanmin.us | perl - App::cpanminus
RUN cpanm -n Bundle::Interchange
RUN cpanm -n DBD::SQLite DBD::Pg DBD::mysql
RUN cpanm -n Plack Plack::Builder Plack::App::WrapCGI Plack::Middleware::Static Plack::Middleware::ForceEnv CGI::Emulate::PSGI CGI::Compile Starman

USER interchange
WORKDIR /home/interchange
COPY --chown=interchange . interchange-src/


# make default catalog, start Interchange
WORKDIR /home/interchange
RUN cp interchange-src/docker/start.sh ./
RUN chmod +x /home/interchange/start.sh
ENTRYPOINT /home/interchange/start.sh

