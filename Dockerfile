FROM python:3

RUN mkdir /srv/backtab/
#RUN apt-get -y update && apt-get install git mercurial
WORKDIR /usr/src/app

COPY requirements.txt  ./
RUN pip install --no-cache-dir -r requirements.txt

COPY src src
COPY setup.py .
RUN python ./setup.py install

WORKDIR /srv/backtab
COPY config.yml.default /etc/backtab.yml
COPY docker-startup.sh /docker-startup.sh

VOLUME /srv/backtab

RUN mkdir /root/.ssh
RUN echo github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl >>/etc/ssh/ssh_known_hosts
RUN git config --global user.name "Backtab server" && git config --global user.email "backtab@example.com"

CMD ["/bin/bash", "/docker-startup.sh"]
EXPOSE 4903