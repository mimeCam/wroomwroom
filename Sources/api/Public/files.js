(function() {
    var params = new URLSearchParams(window.location.search);
    var instancePath = params.get('instance');
    var personaId = params.get('persona');
    var personaName = params.get('name') || personaId;

    var baseUrl = '/api/instances/' + encodeURIComponent(instancePath) + '/personas/' + encodeURIComponent(personaId) + '/knowledge';

    var editor = null;
    var currentFile = null;
    var loadedContent = '';
    var isDirty = false;
    var isNewFile = false;
    var files = [];

    document.getElementById('personaTag').textContent = personaName;
    var shortInstance = instancePath ? instancePath.split('/').pop() : '';
    document.getElementById('instanceTag').textContent = shortInstance;

    function escapeHtml(text) {
        var div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    function initEditor() {
        editor = ace.edit('ace-editor');
        editor.setTheme('ace/theme/chrome');
        editor.setOption('fontSize', 14);
        editor.setOption('fontFamily', "'JetBrains Mono', 'SF Mono', Menlo, Monaco, monospace");
        editor.setOption('showPrintMargin', false);
        editor.setOption('wrap', true);
        editor.setOption('highlightActiveLine', true);
        editor.session.setMode('ace/mode/markdown');
        editor.session.setUseWorker(false);

        editor.on('change', function() {
            updateDirtyState();
        });
    }

    function updateDirtyState() {
        if (!editor) return;
        var current = editor.getValue();
        isDirty = (current !== loadedContent);

        var saveBtn = document.getElementById('saveBtn');
        var saveBar = document.getElementById('saveBar');

        if (isDirty) {
            saveBar.classList.add('visible');
            document.title = '\u2022 ' + (currentFile || 'untitled') + ' \u2014 Knowledge files';
        } else {
            saveBar.classList.remove('visible');
            if (currentFile) {
                document.title = currentFile + ' \u2014 Knowledge files';
            } else {
                document.title = 'Knowledge files';
            }
        }

        if (editor) editor.resize();
    }

    function setModeForFile(filename) {
        if (!editor) return;
        var ext = filename.split('.').pop().toLowerCase();
        var modeMap = {
            'md': 'ace/mode/markdown',
            'txt': 'ace/mode/text',
            'json': 'ace/mode/json',
            'yaml': 'ace/mode/yaml',
            'yml': 'ace/mode/yaml',
            'xml': 'ace/mode/xml',
            'html': 'ace/mode/html',
            'css': 'ace/mode/css',
            'js': 'ace/mode/javascript',
            'ts': 'ace/mode/typescript',
            'py': 'ace/mode/python',
            'sh': 'ace/mode/sh'
        };
        editor.session.setMode(modeMap[ext] || 'ace/mode/markdown');
    }

    function updateStates() {
        var noFilesState = document.getElementById('noFilesState');
        var editorEmpty = document.getElementById('editorEmpty');
        var sidebar = document.getElementById('sidebar');
        var aceEl = document.getElementById('ace-editor');
        var saveBar = document.getElementById('saveBar');

        if (files.length === 0 && !currentFile) {
            noFilesState.style.display = '';
            editorEmpty.style.display = 'none';
            sidebar.classList.add('hidden');
            aceEl.style.display = 'none';
            saveBar.classList.remove('visible');
            return;
        }

        noFilesState.style.display = 'none';
        sidebar.classList.remove('hidden');
        aceEl.style.display = '';
        saveBar.style.display = '';

        if (!currentFile) {
            editorEmpty.style.display = '';
            aceEl.style.display = 'none';
            saveBar.classList.remove('visible');
        } else {
            editorEmpty.style.display = 'none';
            aceEl.style.display = '';
            if (editor) editor.resize();
        }
    }

    async function loadFileList() {
        try {
            var response = await fetch(baseUrl);
            if (!response.ok) throw new Error('Failed to load files');
            var data = await response.json();
            files = data.files || [];
        } catch (err) {
            console.error('Failed to load file list:', err);
            files = [];
        }
        renderFileList();
        updateStates();
    }

    function renderFileList() {
        var listEl = document.getElementById('fileList');
        listEl.innerHTML = files.map(function(name) {
            var isActive = (name === currentFile) ? ' active' : '';
            return '<div class="file-item' + isActive + '" data-file="' + escapeHtml(name) + '">' +
                '<span class="file-name">' + escapeHtml(name) + '</span>' +
                '<button class="file-delete-btn" data-file="' + escapeHtml(name) + '" title="Delete">\u00D7</button>' +
                '</div>';
        }).join('');

        listEl.querySelectorAll('.file-item').forEach(function(item) {
            item.addEventListener('click', function(e) {
                if (e.target.classList.contains('file-delete-btn')) return;
                selectFile(item.dataset.file);
            });
        });

        listEl.querySelectorAll('.file-delete-btn').forEach(function(btn) {
            btn.addEventListener('click', function(e) {
                e.stopPropagation();
                confirmDelete(btn.dataset.file, btn.closest('.file-item'));
            });
        });
    }

    async function selectFile(filename) {
        if (currentFile === filename && !isNewFile) return;
        currentFile = filename;
        isNewFile = false;

        document.querySelectorAll('.file-item').forEach(function(el) {
            el.classList.toggle('active', el.dataset.file === filename);
        });

        updateStates();

        try {
            var response = await fetch(baseUrl + '/' + encodeURIComponent(filename));
            if (!response.ok) throw new Error('Failed to read file');
            var content = await response.text();
            loadedContent = content;
            editor.setValue(content, -1);
            setModeForFile(filename);
            updateDirtyState();
            document.title = filename + ' \u2014 Knowledge files';
        } catch (err) {
            console.error('Failed to load file:', err);
        }
    }

    async function saveFile() {
        if (!isDirty && !isNewFile) return;

        var saveBtn = document.getElementById('saveBtn');
        var filename = currentFile;

        if (!filename) return;

        saveBtn.classList.add('saving');
        saveBtn.textContent = 'Saving...';

        try {
            var content = editor.getValue();
            var response = await fetch(baseUrl + '/' + encodeURIComponent(filename), {
                method: 'PUT',
                headers: { 'Content-Type': 'text/plain' },
                body: content
            });

            if (!response.ok) throw new Error('Failed to save');

            loadedContent = content;
            isDirty = false;
            isNewFile = false;

            saveBtn.classList.remove('saving');
            saveBtn.classList.add('saved');
            saveBtn.textContent = 'Saved \u2713';
            document.title = filename + ' \u2014 Knowledge files';

            setTimeout(function() {
                saveBtn.classList.remove('saved');
                saveBtn.textContent = 'Save';
                document.getElementById('saveBar').classList.remove('visible');
            }, 1500);

            await loadFileList();
        } catch (err) {
            console.error('Failed to save:', err);
            saveBtn.classList.remove('saving');
            saveBtn.classList.add('error');
            saveBtn.textContent = 'Save failed \u2014 retry';
            setTimeout(function() {
                saveBtn.classList.remove('error');
                saveBtn.textContent = 'Save';
                isDirty = true;
                document.getElementById('saveBar').classList.add('visible');
            }, 3000);
        }
    }

    function showNewFileInline() {
        var container = document.getElementById('newFileInline');
        container.innerHTML =
            '<div class="new-file-inline">' +
                '<input type="text" id="newFileInput" placeholder="filename.md" />' +
                '<button class="confirm-btn" id="newFileConfirm">\u2713</button>' +
                '<button class="cancel-btn" id="newFileCancel">\u00D7</button>' +
            '</div>';

        var input = document.getElementById('newFileInput');
        var confirmBtn = document.getElementById('newFileConfirm');
        var cancelBtn = document.getElementById('newFileCancel');

        input.focus();

        function doConfirm() {
            var filename = input.value.trim();
            if (!filename) return;
            if (filename.indexOf('/') !== -1) return;
            createNewFile(filename);
            container.innerHTML = '';
        }

        function doCancel() {
            container.innerHTML = '';
        }

        input.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                doConfirm();
            } else if (e.key === 'Escape') {
                e.preventDefault();
                doCancel();
            }
        });

        confirmBtn.addEventListener('click', doConfirm);
        cancelBtn.addEventListener('click', doCancel);
    }

    function createNewFile(filename) {
        currentFile = filename;
        isNewFile = true;
        loadedContent = '';
        isDirty = true;

        if (files.indexOf(filename) === -1) {
            files.push(filename);
        }

        document.getElementById('noFilesState').style.display = 'none';
        document.getElementById('editorEmpty').style.display = 'none';
        document.getElementById('sidebar').classList.remove('hidden');
        document.getElementById('ace-editor').style.display = '';

        renderFileList();

        editor.setValue('', -1);
        setModeForFile(filename);
        document.title = '\u2022 ' + filename + ' \u2014 Knowledge files';
        updateDirtyState();
        editor.focus();
        editor.resize();
    }

    function confirmDelete(filename, itemEl) {
        var existing = document.querySelector('.file-delete-confirm');
        if (existing) existing.remove();

        var confirmEl = document.createElement('div');
        confirmEl.className = 'file-delete-confirm';
        confirmEl.innerHTML =
            '<span>Delete ' + escapeHtml(filename) + '?</span>' +
            '<button class="del-confirm-yes">Delete</button>' +
            '<button class="del-confirm-no">Cancel</button>';

        itemEl.style.display = 'none';
        itemEl.parentNode.insertBefore(confirmEl, itemEl.nextSibling);

        confirmEl.querySelector('.del-confirm-yes').addEventListener('click', function(e) {
            e.stopPropagation();
            doDelete(filename);
            confirmEl.remove();
            itemEl.remove();
        });

        confirmEl.querySelector('.del-confirm-no').addEventListener('click', function(e) {
            e.stopPropagation();
            confirmEl.remove();
            itemEl.style.display = '';
        });
    }

    async function doDelete(filename) {
        try {
            var response = await fetch(baseUrl + '/' + encodeURIComponent(filename), {
                method: 'DELETE'
            });
            if (!response.ok && response.status !== 404) throw new Error('Failed to delete');

            if (currentFile === filename) {
                currentFile = null;
                loadedContent = '';
                editor.setValue('', -1);
                isNewFile = false;
                isDirty = false;
                document.getElementById('saveBar').classList.remove('visible');
            }
            await loadFileList();
        } catch (err) {
            console.error('Failed to delete file:', err);
        }
    }

    document.getElementById('saveBtn').addEventListener('click', saveFile);

    document.getElementById('newFileBtn').addEventListener('click', showNewFileInline);

    document.addEventListener('keydown', function(e) {
        if ((e.metaKey || e.ctrlKey) && e.key === 's') {
            e.preventDefault();
            saveFile();
        }
    });

    window.addEventListener('beforeunload', function(e) {
        if (isDirty) {
            e.preventDefault();
            e.returnValue = '';
        }
    });

    initEditor();
    loadFileList();
})();
