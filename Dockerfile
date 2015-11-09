FROM fedora:22

WORKDIR /data/

RUN mkdir -p /data/GreenTea
ADD . /data/GreenTea/

# install packages
RUN dnf install git findutils -y \
    && curl https://beaker-project.org/yum/beaker-client-Fedora.repo -o /etc/yum.repos.d/beaker-client-Fedora.repo \
    && cat GreenTea/requirement/rpms-*.txt | xargs dnf install -y \
    && dnf clean all \
    && chmod 755 /data/ -R

# create enviroment
RUN useradd -ms /bin/bash greentea \
    && chown greentea:greentea -R GreenTea

RUN echo "root:GreenTea!" | chpasswd

# fixed CA for Red Hat
# ADD /.bin/redhat-update-ca.sh $HOME/bin/docker-run.sh
# RUN sh $HOME/bin/redhat-update-ca.sh

USER greentea
ENV HOME /data/GreenTea

RUN virtualenv $HOME/env \
    && cd $HOME \
    && . env/bin/activate \
    && pip install -r $HOME/requirement/requirement.txt

# create default value for running service
RUN python -c 'import random; print "import os\nfrom basic import *\nDEBUG=True\nSECRET_KEY=\"" + "".join([random.choice("abcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*(-_=+)") for i in range(50)]) + "\"" ' > GreenTea/tttt/settings/production.py 

RUN mkdir -p $HOME/tttt/static \
    && . $HOME/env/bin/activate \
    && python $HOME/manage.py syncdb --noinput \
    && python $HOME/manage.py migrate \
    && python $HOME/manage.py collectstatic -c --noinput

# create first user
RUN . $HOME/env/bin/activate && \
    echo 'from django.contrib.sites.models import Site; site = Site.objects.create(domain="localhost", name="localhost"); site.save()' | python $HOME/manage.py shell && \
    echo 'from django.contrib.auth.models import User; User.objects.create_superuser("admin", "admin@example.com", "pass")' | python $HOME/manage.py shell

# install cron and enable cron
# it doesn't use for docker, only for real system
# RUN yum install crontabs -y && mv $HOME/tttt/conf/cron/greentea.cron /etc/cron.d/

ADD ./bin/docker-run.sh $HOME/bin/docker-run.sh

EXPOSE 8000

CMD sh $HOME/bin/docker-run.sh
