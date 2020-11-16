FROM ruby:2.5.8-alpine as base

RUN apk --no-cache add bash openjdk11-jdk

FROM base as compiler

RUN apk --no-cache add git maven

# DATA LOADER
WORKDIR /tmp

RUN git clone https://github.com/forcedotcom/dataloader.git && \
    cd dataloader && \
    git submodule init && \
    git submodule update && \
    mvn clean package -DskipTests

FROM base as jobber

WORKDIR /opt/app

# RUN mkdir configs && mkdir libs

COPY --from=compiler /tmp/dataloader/target/dataloader-*-uber.jar ./dataloader.jar
# COPY --from=compiler /tmp/dataloader/release/mac/configs ./configs/sample

# SCHEDULING
# ARG JOBBER_VERSION=1.4.0
# ENV USER=dataloader
# ENV USER_ID=1000

# RUN addgroup ${USER} && adduser -S -u "${USER_ID}" ${USER}

# RUN wget -O /tmp/jobber.apk "https://github.com/dshearer/jobber/releases/download/v${JOBBER_VERSION}/jobber-${JOBBER_VERSION}-r0.apk" && \
#     apk add --no-network --no-scripts --allow-untrusted /tmp/jobber.apk && \
#     rm /tmp/jobber.apk && \
#     mkdir -p "/var/jobber/${USER_ID}" && \
#     chown -R ${USER} "/var/jobber/${USER_ID}"

# COPY --chown=${USER} jobfile /home/${USER}/.jobber
# RUN chown -R ${USER} configs && \
#     chown -R ${USER} libs && \
#     chmod 0600 /home/${USER}/.jobber

# WRAPPING UP
COPY dataloader ./

ENV PATH=/opt/app:${PATH}
# USER ${USER}

# VOLUME ["/opt/app/configs"]
# VOLUME ["/opt/app/libs"]

# CMD ["/usr/libexec/jobberrunner", "-u", "/var/jobber/1000/cmd.sock", "/home/dataloader/.jobber"]

FROM jobber as app

RUN gem install bundler

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY ./ ./

RUN chmod +x dataloader
