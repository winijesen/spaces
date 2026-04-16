FROM node:22-slim AS nodebuilder

FROM python:3.11-slim-bookworm AS builder
ARG QL_MAINTAINER="whyour"
LABEL maintainer="${QL_MAINTAINER}"
ARG QL_URL=https://github.com/${QL_MAINTAINER}/qinglong.git
ARG QL_BRANCH=debian
ENV QL_DIR=/ql_tmp

COPY --from=nodebuilder /usr/local/bin/node /usr/local/bin/
COPY --from=nodebuilder /usr/local/lib/node_modules/. /usr/local/lib/node_modules/

RUN set -x && \
  ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
  apt-get update && \
  apt-get install --no-install-recommends -y libatomic1 git && \
  git clone --depth=1 -b ${QL_BRANCH} ${QL_URL} ${QL_DIR} && \
  mkdir /tmp/build && \
  cp ${QL_DIR}/package.json ${QL_DIR}/.npmrc ${QL_DIR}/pnpm-lock.yaml /tmp/build/ && \
  npm i -g pnpm@8.3.1 && \
  cd /tmp/build && \
  pnpm install --prod && \
  pnpm add reflect-metadata && \
  rm -rf ${QL_DIR}


FROM python:3.11-slim-bookworm

ARG QL_MAINTAINER="whyour"
LABEL maintainer="${QL_MAINTAINER}"
ARG QL_URL=https://github.com/${QL_MAINTAINER}/qinglong.git
ARG QL_BRANCH=debian
ARG PYTHON_SHORT_VERSION=3.11

ENV REMOTE_FOLDER="huggingface:/qinglong"
ENV QL_DIR=/ql \
  QL_BRANCH=${QL_BRANCH} \
  LANG=C.UTF-8 \
  SHELL=/bin/bash \
  PS1="\u@\h:\w \$ "

ARG QL_UID=5432
ARG QL_GID=5432
RUN groupadd -g ${QL_GID} coder && \
    useradd -m -u ${QL_UID} -g ${QL_GID} -s /bin/bash coder && \
    mkdir -p /home/coder/bin /home/coder/.ssh && \
    chmod 700 /home/coder/.ssh && \
    chown -R ${QL_UID}:${QL_GID} /home/coder

ENV QL_USER=coder
ENV QL_HOME=/home/$QL_USER

COPY --from=nodebuilder /usr/local/bin/node /usr/local/bin/
COPY --from=nodebuilder /usr/local/lib/node_modules/. /usr/local/lib/node_modules/

# ⭐ 复制 builder 阶段的 node_modules（解决 reflect-metadata）
COPY --from=builder /tmp/build/node_modules /usr/local/lib/node_modules

RUN set -x && \
  ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
  ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
  apt-get update && \
  apt-get upgrade -y && \
  apt-get install --no-install-recommends -y git \
  curl \
  wget \
  tzdata \
  perl \
  openssl \
  openssh-client \
  jq \
  procps \
  netcat-openbsd \
  unzip \
  libatomic1 \
  nginx \
  rclone \
  sshpass && \
  apt-get clean && \
  ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
  echo "Asia/Shanghai" >/etc/timezone && \
  git config --global user.email "qinglong@users.noreply.github.com" && \
  git config --global user.name "qinglong" && \
  git config --global http.postBuffer 524288000 && \
  npm install -g pnpm@8.3.1 pm2 ts-node && \
  rm -rf /root/.cache && \
  rm -rf /root/.npm && \
  rm -rf /etc/apt/apt.conf.d/docker-clean && \
  ulimit -c 0

# 安装 code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version=4.96.4

RUN mkdir -p ${QL_DIR} && \
  chown -R ${QL_UID}:${QL_GID} ${QL_DIR}

RUN chmod -R 777 /ql && \
  chmod -R 777 /var && \
  chmod -R 777 /usr/local && \
  chmod -R 777 /etc/nginx && \
  chmod -R 777 /run && \
  chmod -R 777 /usr && \
  chmod -R 777 /root 


# ⭐ 调试：列出所有 nginx 配置文件
RUN echo "=== CONF.D LIST ===" && ls -l /etc/nginx/conf.d && \
    echo "=== SITES-ENABLED LIST ===" && ls -l /etc/nginx/sites-enabled || true

# ⭐ 删除默认 nginx 配置（避免 80 端口冲突）
RUN rm -f /etc/nginx/conf.d/default.conf && \
    rm -f /etc/nginx/sites-enabled/default


# ⭐ 复制你修复后的 front.conf
COPY front.conf /etc/nginx/conf.d/front.conf

COPY notify.py /notify.py

USER coder
ARG SOURCE_COMMIT
RUN git clone --depth=1 -b ${QL_BRANCH} ${QL_URL} ${QL_DIR} && \
  cd ${QL_DIR} && \
  cp -f .env.example .env && \
  chmod 777 ${QL_DIR}/shell/*.sh && \
  chmod 777 ${QL_DIR}/docker/*.sh && \
  git clone --depth=1 -b ${QL_BRANCH} https://github.com/${QL_MAINTAINER}/qinglong-static.git /tmp/static && \
  mkdir -p ${QL_DIR}/static && \
  cp -rf /tmp/static/* ${QL_DIR}/static && \
  rm -rf /tmp/static

ENV PNPM_HOME=${QL_DIR}/data/dep_cache/node \
  PYTHON_HOME=${QL_DIR}/data/dep_cache/python3 \
  PYTHONUSERBASE=${QL_DIR}/data/dep_cache/python3

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PNPM_HOME}:${PYTHON_HOME}/bin \
  NODE_PATH=/usr/local/bin:/usr/local/lib/node_modules:${PNPM_HOME}/global/5/node_modules \
  PIP_CACHE_DIR=${PYTHON_HOME}/pip \
  PYTHONPATH=${PYTHON_HOME}:${PYTHON_HOME}/lib/python${PYTHON_SHORT_VERSION}:${PYTHON_HOME}/lib/python${PYTHON_SHORT_VERSION}/site-packages

RUN pip3 install --prefix ${PYTHON_HOME} requests

USER root

# ⭐ 不再删除青龙官方 entrypoint
# RUN rm -f ${QL_DIR}/docker/docker-entrypoint.sh

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
USER coder

WORKDIR ${QL_DIR}

HEALTHCHECK --interval=5s --timeout=2s --retries=20 \
  CMD curl -sf --noproxy '*' http://127.0.0.1:5700/api/health || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

VOLUME /ql/data
  
EXPOSE 80
