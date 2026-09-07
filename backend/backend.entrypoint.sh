#!/bin/sh

set -e

echo "Waiting for PostgreSQL at $DB_HOST:$DB_PORT..."

# -q silences pg_isready; the loop runs until it reports success
while ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -q; do
  echo "PostgreSQL is not reachable yet, retrying in 1 second"
  sleep 1
done

echo "PostgreSQL is ready, continuing..."

# Collect static files, then bring the database schema up to date
python manage.py collectstatic --noinput
python manage.py migrate

# Create a superuser using environment variables
python manage.py shell <<EOF
import os
from django.contrib.auth import get_user_model

User = get_user_model()
username = os.environ.get('DJANGO_SUPERUSER_USERNAME')
email = os.environ.get('DJANGO_SUPERUSER_EMAIL')
password = os.environ.get('DJANGO_SUPERUSER_PASSWORD')

if not (username and email and password):
    print("Skipping superuser: DJANGO_SUPERUSER_* is not fully set.")
elif User.objects.filter(username=username).exists():
    print(f"Superuser '{username}' already exists.")
else:
    # username is required by create_superuser, even though login uses the email
    User.objects.create_superuser(username=username, email=email, password=password)
    print(f"Superuser '{username}' created.")
EOF

python manage.py rqworker high default low &
python manage.py rqworker high default low &

exec gunicorn core.wsgi:application --bind 0.0.0.0:8000 --reload
