# Локальная модель в Ollama

Скачайте GGUF самостоятельно и сохраните его вне этого публичного репозитория. Для ранее выбранной модели GPT4chan 8B использовался файл `GPT4chan-8B.Q4_K_S.gguf` (около 4,7 ГБ). Проверьте свободное место перед импортом.

```powershell
.\ollama\Import-GGUF.ps1 -ModelPath 'D:\Models\GPT4chan-8B.Q4_K_S.gguf'
.\ollama\Import-GGUF.ps1 -ModelPath 'D:\Models\GPT4chan-8B.Q4_K_S.gguf' -Apply
ollama list
```

Модель используется в приложении Ollama для обычной переписки. Она не подключается к DeepSeek Harness и не получает его инструменты или файлы. Ollama может держать запущенную модель в памяти после ответа. Освободить память: `ollama stop gpt4chan-chat`; посмотреть загруженные модели: `ollama ps`.

Если Ollama стоит в нестандартной папке, добавьте `-OllamaExe 'G:\Ai\Ollama\ollama.exe'` к команде импорта.

Импорт не копирует GGUF в GitHub. На другом ПК повторите импорт из своей сохранённой копии файла. [Официальная документация Ollama](https://github.com/ollama/ollama/blob/main/docs/import.mdx).

