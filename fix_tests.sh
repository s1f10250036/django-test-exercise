#!/bin/bash
set -euo pipefail

WORKDIR="$HOME/SW-exercise1/ex11/django-test-exercise"
cd "$WORKDIR" || { echo "Directory not found: $WORKDIR"; exit 1; }

# バックアップ
cp todo/tests.py todo/tests.py.bak
echo "Backup created: todo/tests.py.bak"

# 上書き内容を一時ファイルに書く
TMPFILE=$(mktemp)
cat > "$TMPFILE" <<'PYTEST'
from django.test import TestCase, Client
from django.utils import timezone
from datetime import datetime
from todo.models import Task


class SampleTestCase(TestCase):
    def test_sample1(self):
        self.assertEqual(1 + 2, 3)


class TaskModelTestCase(TestCase):
    def test_create_task1(self):
        due = timezone.make_aware(datetime(2024, 6, 30, 23, 59, 59))
        task = Task(title='task1', due_at=due)
        task.save()

        task = Task.objects.get(pk=task.pk)
        self.assertEqual(task.title, 'task1')
        self.assertFalse(task.completed)
        self.assertEqual(task.due_at, due)

    def test_create_task2(self):
        task = Task(title='task2')
        task.save()

        task = Task.objects.get(pk=task.pk)
        self.assertEqual(task.title, 'task2')
        self.assertFalse(task.completed)
        self.assertEqual(task.due_at, None)

    def test_is_overdue_future(self):
        due = timezone.make_aware(datetime(2024, 6, 30, 23, 59, 59))
        current = timezone.make_aware(datetime(2024, 6, 30, 0, 0, 0))
        task = Task(title='task1', due_at=due)
        task.save()

        self.assertFalse(task.is_overdue(current))

    def test_is_overdue_past(self):
        due = timezone.make_aware(datetime(2024, 6, 30, 23, 59, 59))
        later = timezone.make_aware(datetime(2024, 7, 1, 0, 0, 0))
        task = Task(title='task1', due_at=due)
        task.save()

        self.assertTrue(task.is_overdue(later))

    def test_is_overdue_none(self):
        current = timezone.make_aware(datetime(2024, 7, 10, 0, 0, 0))
        task = Task(title='task_no_due')
        task.save()

        self.assertFalse(task.is_overdue(current))

    def test_index_get(self):
        client = Client()
        response = client.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.templates[0].name, 'todo/index.html')
        self.assertEqual(len(response.context['tasks']), 0)

    def test_index_post(self):
        client = Client()
        data = {'title': 'Test Task', 'due_at': '2024-06-30 23:59:59'}
        response = client.post('/', data)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.templates[0].name, 'todo/index.html')
        self.assertEqual(len(response.context['tasks']), 1)

    def test_index_get_order_post(self):
        task1 = Task(title='task1', due_at=timezone.make_aware(datetime(2024, 7, 1)))
        task1.save()
        task2 = Task(title='task2', due_at=timezone.make_aware(datetime(2024, 8, 1)))
        task2.save()
        client = Client()
        response = client.get('/?order=post')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.templates[0].name, 'todo/index.html')
        self.assertEqual(response.context['tasks'][0], task2)
        self.assertEqual(response.context['tasks'][1], task1)

    def test_index_get_order_due(self):
        task1 = Task(title='task1', due_at=timezone.make_aware(datetime(2024, 7, 1)))
        task1.save()
        task2 = Task(title='task2', due_at=timezone.make_aware(datetime(2024, 8, 1)))
        task2.save()
        client = Client()
        response = client.get('/?order=due')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.templates[0].name, 'todo/index.html')
        self.assertEqual(response.context['tasks'][0], task1)
        self.assertEqual(response.context['tasks'][1], task2)
PYTEST

# 移動して上書き
mv "$TMPFILE" todo/tests.py
chmod 644 todo/tests.py
printf "\n" >> todo/tests.py

# 構文チェック
python -m py_compile todo/tests.py
echo "py_compile: OK"

# flake8 fatal checks
python -m pip install --upgrade pip
python -m pip install flake8
flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
echo "flake8 fatal checks: OK"

# ローカルテスト
python manage.py test
echo "local tests: OK"

# Git commit & push
git add todo/tests.py
if git commit -m "Fix: normalize indentation and formatting in todo/tests.py to satisfy flake8"; then
  echo "Committed changes."
else
  echo "No changes to commit."
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $BRANCH"

if git push origin "$BRANCH"; then
  echo "Pushed to origin/$BRANCH"
else
  echo "Push failed (protected branch?). Creating branch fix/tests-format and pushing it."
  git checkout -b fix/tests-format
  git push origin fix/tests-format
  echo "Pushed to origin/fix/tests-format — open a PR from this branch."
fi

echo "All done. Check GitHub Actions for CI run."
