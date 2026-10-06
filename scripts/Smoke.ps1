param([string]$BaseUrl = 'http://localhost:8080')
$ErrorActionPreference = 'Stop'

function Request([string]$Method, [string]$Path, $Body, [int]$Expected) {
    $parameters = @{ Uri = "$BaseUrl$Path"; Method = $Method; SkipHttpErrorCheck = $true }
    if ($null -ne $Body) {
        $parameters.ContentType = 'application/json'
        $parameters.Body = ConvertTo-Json $Body -Depth 5
    }
    $response = Invoke-WebRequest @parameters
    if ([int]$response.StatusCode -ne $Expected) {
        throw "$Method $Path expected $Expected, received $($response.StatusCode): $($response.Content)"
    }
    Write-Host "PASS $Method $Path -> $Expected"
    if ($response.Content) { return ($response.Content | ConvertFrom-Json) }
}

function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

Request 'GET' '/health' $null 200 | Out-Null
$project = Request 'POST' '/api/projects' @{ name = "Smoke-$([Guid]::NewGuid().ToString('N'))" } 201
Request 'GET' "/api/projects/$($project.id)" $null 200 | Out-Null
Request 'POST' '/api/projects' @{ name = $project.name } 409 | Out-Null
Request 'POST' '/api/projects' @{ name = '   ' } 400 | Out-Null
$taskBody = @{ projectId = $project.id; title = '  Check SQL persistence  '; description = 'demo'; dueDate = '2026-10-20'; status = 'Todo' }
$task = $null
try {
    $task = Request 'POST' '/api/tasks' $taskBody 201
    Assert ($task.title -eq 'Check SQL persistence') 'Title should be trimmed.'
    $read = Request 'GET' "/api/tasks/$($task.id)" $null 200
    Assert ($read.projectName -eq $project.name) 'Project relation was not saved.'
    Assert ($read.dueDate -eq '2026-10-20') 'Due date was not saved.'
    $list = Request 'GET' "/api/tasks?projectId=$($project.id)&search=SQL&status=Todo&pageSize=1" $null 200
    Assert ($list.total -eq 1 -and $list.items[0].id -eq $task.id) 'Filtering or pagination is wrong.'
    $taskBody.title = '   '
    Request 'POST' '/api/tasks' $taskBody 400 | Out-Null
    $taskBody.title = 'x' * 121
    Request 'POST' '/api/tasks' $taskBody 400 | Out-Null
    $taskBody.title = 'Valid title'
    $taskBody.projectId = 2147483647
    Request 'POST' '/api/tasks' $taskBody 400 | Out-Null
    $taskBody.projectId = $project.id
    $taskBody.status = 'Unknown'
    Request 'POST' '/api/tasks' $taskBody 400 | Out-Null
    $taskBody.status = 99
    Request 'POST' '/api/tasks' $taskBody 400 | Out-Null
    $taskBody.status = 'Done'
    $updated = Request 'PUT' "/api/tasks/$($task.id)" $taskBody 200
    Assert ($updated.status -eq 'Done') 'Status was not updated.'
    $todo = Request 'GET' "/api/tasks?projectId=$($project.id)&status=Todo" $null 200
    Assert ($todo.total -eq 0) 'Completed task still appears as Todo.'
    Request 'GET' '/api/tasks?page=0' $null 400 | Out-Null
    Request 'GET' '/api/tasks?pageSize=101' $null 400 | Out-Null
    Request 'GET' '/api/tasks?status=99' $null 400 | Out-Null
    Request 'GET' '/api/tasks/2147483647' $null 404 | Out-Null
    Request 'PUT' '/api/tasks/2147483647' $taskBody 404 | Out-Null
    Request 'DELETE' "/api/tasks/$($task.id)" $null 204 | Out-Null
    Request 'GET' "/api/tasks/$($task.id)" $null 404 | Out-Null
    Request 'DELETE' "/api/tasks/$($task.id)" $null 404 | Out-Null
    Write-Host 'All API smoke checks passed against the configured database.'
} finally {
    if ($task) {
        Invoke-WebRequest -Uri "$BaseUrl/api/tasks/$($task.id)" -Method Delete -SkipHttpErrorCheck | Out-Null
    }
}
# The empty, uniquely named smoke project is retained; no unrelated rows are removed.
