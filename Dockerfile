## BUILDING
##   (from project root directory)
##   $ docker build -t php-for-danadalis-lemh-server .
##
## RUNNING
##   $ docker run -p 9000:9000 php-for-danadalis-lemh-server
##
## CONNECTING
##   Lookup the IP of your active docker host using:
##     $ docker-machine ip $(docker-machine active)
##   Connect to the container at DOCKER_IP:9000
##     replacing DOCKER_IP for the IP of your active docker host

FROM gcr.io/stacksmith-images/ubuntu-buildpack:14.04-r10

MAINTAINER Bitnami <containers@bitnami.com>

ENV STACKSMITH_STACK_ID="5fw2bix" \
    STACKSMITH_STACK_NAME="PHP for danadalis/LEMH-Server" \
    STACKSMITH_STACK_PRIVATE="1"

RUN bitnami-pkg install php-7.0.12-0 --checksum 72ad07dae640cd2a34bccf7c81bbe4a1ec7cd55eec40fc4dc8eef7a450be493a

ENV PATH=/opt/bitnami/php/bin:$PATH

## STACKSMITH-END: Modifications below this line will be unchanged when regenerating

# PHP base template
COPY . /app
WORKDIR /app

CMD ["php", "-a"]
