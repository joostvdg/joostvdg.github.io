FROM nginx:mainline

LABEL authors="Joost van der Griendt <joostvdg@gmail.com>"
LABEL version="1.0.0"
LABEL description="Mr J's knowledge base"

RUN apt-get update && apt-get install --no-install-recommends -y curl=7.* && rm -rf /var/lib/apt/lists/*
HEALTHCHECK CMD curl --fail http://localhost:80/docs/ || exit 1
COPY site/ /usr/share/nginx/html/docs
RUN ls -lath /usr/share/nginx/html/docs
