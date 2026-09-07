FROM python:3.12-alpine

LABEL description="Videoflix backend: Django REST API with HLS video conversion"

WORKDIR /app

# Copy the dependency list on its own first. This layer is then only rebuilt
# when requirements.txt changes, not on every code change.
COPY requirements.txt .

RUN apk update && \
    apk add --no-cache --upgrade bash && \
    apk add --no-cache postgresql-client ffmpeg && \
    apk add --no-cache --virtual .build-deps gcc musl-dev postgresql-dev && \
    pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    apk del .build-deps

COPY . .

RUN chmod +x backend.entrypoint.sh

EXPOSE 8000

ENTRYPOINT [ "./backend.entrypoint.sh" ]
