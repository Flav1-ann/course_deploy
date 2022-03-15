FROM openjdk:15-jdk-alpine


LABEL MAINTENER="Flavien ANNAIX"


RUN apk update && \
    apk upgrade && \
    apk add git &&\
    apk add maven &&\
    apk add bash

RUN git clone https://github.com/Flav1-ann/course /course

WORKDIR /course

RUN mvn clean package

RUN cp target/*.jar app.jar

RUN addgroup -S spring && adduser -S spring -G spring

USER spring:spring

ENTRYPOINT ["java","-jar","app.jar"]