from django.shortcuts import render
from django.http import Http404
from django.utils import timezone
from datetime import datetime
from todo.models import Task


def _parse_due_at(s):
    s = (s or '').strip()
    if not s:
        return None
    try:
        dt = datetime.strptime(s, "%Y-%m-%d %H:%M:%S")
        if timezone.is_naive(dt):
            dt = timezone.make_aware(dt)
        return dt
    except Exception:
        return None


def index(request):
    # POST: タスク作成（テストが要求）
    if request.method == 'POST':
        title = request.POST.get('title', '').strip()
        due_at = _parse_due_at(request.POST.get('due_at', ''))
        if title:
            Task.objects.create(
                title=title,
                due_at=due_at,
                posted_at=timezone.now()
            )

    # GET: 並び替え（テストが要求）
    order = request.GET.get('order', '')
    tasks = Task.objects.all()

    if order == 'post':
        tasks = tasks.order_by('-pk')  # 新しい順（テスト仕様）
    elif order == 'due':
        tasks = tasks.order_by('due_at', 'pk')  # 期日順

    return render(request, 'todo/index.html', {'tasks': tasks})


def detail(request, task_id):
    try:
        task = Task.objects.get(pk=task_id)
    except Task.DoesNotExist:
        raise Http404("Task does not exist")

    return render(request, 'todo/detail.html', {'task': task})
