FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

ARG PIPENV_DEV=False
ARG USER_ID=1000

ENV PYTHON_VERSION=3.8 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    PIP_NO_CACHE_DIR=1 \
    PIPENV_VENV_IN_PROJECT=1 \
    PIPENV_VERBOSITY=-1 \
    APP_ROOT=/opt/kokudaily \
    APP_HOME=/opt/kokudaily/kokudaily \
    PLATFORM="el8"

ENV SUMMARY="Koku-daily is a metrics collector for the Cost Management application" \
    DESCRIPTION="Koku-daily is a metrics collector for the Cost Management application"

LABEL summary="$SUMMARY" \
    description="$DESCRIPTION" \
    io.k8s.description="$DESCRIPTION" \
    io.k8s.display-name="Koku-daily" \
    io.openshift.tags="builder,python,python38,rh-python38" \
    com.redhat.component="python38-docker" \
    name="Koku-daily" \
    version="1" \
    maintainer="Red Hat Cost Management Services"

USER root

# Very minimal set of packages
# glibc-langpack-en is needed to set locale to en_US and disable warning about it
# gcc to compile some python packages (e.g. ciso8601)
# shadow-utils to make useradd available
RUN INSTALL_PKGS="python38 python38-devel glibc-langpack-en gcc shadow-utils" && \
    microdnf --nodocs -y upgrade && \
    microdnf -y --setopt=tsflags=nodocs --setopt=install_weak_deps=0 install $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    microdnf -y clean all --enablerepo='*'

# Create a Python virtual environment for use by any application to avoid
# potential conflicts with Python packages preinstalled in the main Python
# installation.
RUN python3.8 -m venv /pipenv-venv
ENV PATH="/pipenv-venv/bin:$PATH"
# Install pipenv into the virtual env
RUN \
    pip install --upgrade pip && \
    pip install pipenv

WORKDIR ${APP_ROOT}

# install dependencies
COPY Pipfile .
COPY Pipfile.lock .
RUN \
    # install the dependencies into the working dir (i.e. ${APP_ROOT}/.venv)
    pipenv install --deploy && \
    # delete the pipenv cache
    pipenv --clear

# Runtime env variables:
ENV VIRTUAL_ENV=${APP_ROOT}/.venv
ENV \
    # Add the koku virtual env bin to the front of PATH.
    # This activates the virtual env for all subsequent python calls.
    PATH="$VIRTUAL_ENV/bin:$PATH" \
    PROMETHEUS_MULTIPROC_DIR=/tmp

# copy the src files into the workdir
COPY kokudaily kokudaily
COPY app.py .
COPY job.py .

# create the koku user
RUN \
    adduser koku -u ${USER_ID} -g 0 && \
    chmod ug+rw ${APP_ROOT} ${APP_HOME} /tmp
USER koku

# Set the default CMD.
CMD ["python", "job.py"]
