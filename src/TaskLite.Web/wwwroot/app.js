const taskForm = document.querySelector('#task-form');
const filterForm = document.querySelector('#filter-form');
const statusLabels = { Todo: 'Do zrobienia', InProgress: 'W trakcie', Done: 'Zrobione' };
let page = 1;
let visibleTasks = [];
let projectRequestVersion = 0;

function message(text, error = false) {
  const box = document.querySelector('#message');
  box.textContent = text;
  box.classList.toggle('error', error);
}

async function api(path, options = {}) {
  const response = await fetch(path, { ...options, cache: 'no-store', headers: { 'Content-Type': 'application/json' } });
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    throw new Error(body.error || Object.values(body.errors || {}).flat().join(' ') || `Błąd HTTP ${response.status}`);
  }
  return response.status === 204 ? null : response.json();
}

async function loadProjects() {
  const requestVersion = ++projectRequestVersion;
  const projects = await api('/api/projects');
  if (requestVersion !== projectRequestVersion) return;
  for (const selector of ['#project-select', '#project-filter']) {
    const select = document.querySelector(selector);
    const previous = select.value;
    select.replaceChildren();
    if (selector === '#project-filter') select.add(new Option('Wszystkie', ''));
    for (const project of projects) select.add(new Option(project.name, project.id));
    if ([...select.options].some(option => option.value === previous)) select.value = previous;
  }
  const list = document.querySelector('#projects');
  list.replaceChildren();
  if (!projects.length) {
    const empty = document.createElement('li'); empty.textContent = 'Brak projektów. Dodaj pierwszy.'; list.append(empty);
  }
  for (const project of projects) {
    const row = document.createElement('li');
    const name = document.createElement('span'); name.textContent = project.name;
    const button = document.createElement('button'); button.type = 'button'; button.className = 'secondary';
    button.textContent = 'Usuń'; button.dataset.id = project.id; button.dataset.action = 'delete';
    button.setAttribute('aria-label', `Usuń projekt ${project.name}`);
    row.append(name, button); list.append(row);
  }
  document.querySelector('#save-task').disabled = projects.length === 0;
}

async function loadTasks() {
  const params = new URLSearchParams();
  for (const [key, value] of new FormData(filterForm)) if (value.trim()) params.set(key, value.trim());
  params.set('page', page); params.set('pageSize', 10);
  const result = await api(`/api/tasks?${params}`);
  if (page > 1 && result.items.length === 0) { page--; return loadTasks(); }
  visibleTasks = result.items;
  const list = document.querySelector('#tasks');
  list.replaceChildren();
  if (!result.items.length) list.textContent = 'Brak zadań. Dodaj pierwsze albo zmień filtry.';
  for (const task of result.items) {
    const card = document.createElement('article');
    const title = document.createElement('h3'); title.textContent = task.title;
    const meta = document.createElement('p'); meta.className = 'meta';
    meta.textContent = `${task.projectName} · ${statusLabels[task.status]} · Termin: ${task.dueDate || 'brak'}`;
    const description = document.createElement('p'); description.textContent = task.description || '';
    const actions = document.createElement('div'); actions.className = 'actions';
    for (const [label, action] of [['Edytuj', 'edit'], ['Usuń', 'delete']]) {
      const button = document.createElement('button'); button.textContent = label; button.className = 'secondary';
      button.dataset.action = action; button.dataset.id = task.id; actions.append(button);
    }
    card.append(title, meta, description, actions); list.append(card);
  }
  document.querySelector('#summary').textContent = `Zadania: ${result.total}`;
  document.querySelector('#page-label').textContent = `Strona ${page}`;
  document.querySelector('#previous').disabled = page === 1;
  document.querySelector('#next').disabled = page * 10 >= result.total;
}

function resetEditor() {
  taskForm.reset(); taskForm.elements.id.value = '';
  document.querySelector('#form-heading').textContent = 'Nowe zadanie';
  document.querySelector('#cancel-edit').hidden = true;
}

async function perform(action) { try { await action(); } catch (error) { message(error.message, true); } }

document.querySelector('#project-form').addEventListener('submit', event => {
  event.preventDefault(); perform(async () => {
    const form = event.currentTarget;
    await api('/api/projects', { method: 'POST', body: JSON.stringify({ name: form.elements.name.value }) });
    form.reset(); await loadProjects(); message('Projekt dodany.');
  });
});

document.querySelector('#projects').addEventListener('click', event => {
  const button = event.target.closest('button[data-id]'); if (!button) return;
  const row = button.closest('li');
  const name = row.querySelector('span').textContent;
  if (button.dataset.action === 'delete') {
    button.dataset.action = 'confirm'; button.textContent = 'Potwierdź';
    button.setAttribute('aria-label', `Potwierdź usunięcie projektu ${name}`);
    const cancel = document.createElement('button'); cancel.type = 'button'; cancel.className = 'secondary';
    cancel.textContent = 'Anuluj'; cancel.dataset.action = 'cancel'; cancel.dataset.id = button.dataset.id;
    cancel.setAttribute('aria-label', `Anuluj usunięcie projektu ${name}`);
    row.append(cancel);
    message(`Potwierdź usunięcie projektu „${name}” albo anuluj.`);
    return;
  }
  if (button.dataset.action === 'cancel') {
    const confirmButton = row.querySelector('button[data-action="confirm"]');
    confirmButton.dataset.action = 'delete'; confirmButton.textContent = 'Usuń';
    confirmButton.setAttribute('aria-label', `Usuń projekt ${name}`);
    button.remove(); message('Usuwanie anulowane.'); return;
  }
  button.disabled = true;
  perform(async () => {
    try {
      await api(`/api/projects/${button.dataset.id}`, { method: 'DELETE' });
      await loadProjects();
      page = 1;
      await loadTasks();
      message('Projekt usunięty.');
    } finally { button.disabled = false; }
  });
});

taskForm.addEventListener('submit', event => {
  event.preventDefault(); perform(async () => {
    const values = Object.fromEntries(new FormData(taskForm));
    const body = { projectId: Number(values.projectId), title: values.title, description: values.description || null, dueDate: values.dueDate || null, status: values.status };
    await api(values.id ? `/api/tasks/${values.id}` : '/api/tasks', { method: values.id ? 'PUT' : 'POST', body: JSON.stringify(body) });
    resetEditor(); await loadTasks(); message('Zadanie zapisane.');
  });
});

document.querySelector('#tasks').addEventListener('click', event => {
  const button = event.target.closest('button[data-action]'); if (!button) return;
  const id = Number(button.dataset.id);
  if (button.dataset.action === 'edit') {
    const task = visibleTasks.find(item => item.id === id);
    for (const field of ['id', 'projectId', 'title', 'description', 'dueDate', 'status']) taskForm.elements[field].value = task[field] ?? '';
    document.querySelector('#form-heading').textContent = 'Edytuj zadanie';
    document.querySelector('#cancel-edit').hidden = false;
    taskForm.elements.title.focus();
  } else if (confirm('Usunąć to zadanie?')) perform(async () => {
    await api(`/api/tasks/${id}`, { method: 'DELETE' });
    if (Number(taskForm.elements.id.value) === id) resetEditor();
    await loadTasks(); message('Zadanie usunięte.');
  });
});

filterForm.addEventListener('submit', event => { event.preventDefault(); page = 1; perform(loadTasks); });
document.querySelector('#cancel-edit').addEventListener('click', resetEditor);
document.querySelector('#previous').addEventListener('click', () => { page--; perform(loadTasks); });
document.querySelector('#next').addEventListener('click', () => { page++; perform(loadTasks); });
window.addEventListener('focus', () => perform(async () => { await loadProjects(); await loadTasks(); }));
document.addEventListener('visibilitychange', () => {
  if (!document.hidden) perform(async () => { await loadProjects(); await loadTasks(); });
});
perform(async () => { await loadProjects(); await loadTasks(); });
